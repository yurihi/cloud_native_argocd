# PowerShell용 도메인 설정 스크립트
# 사용법: .\setup-domain.ps1 -Domain "yourcompany.com" -Subdomain "api"

param(
    [Parameter(Mandatory=$true)]
    [string]$Domain,
    
    [Parameter(Mandatory=$true)]
    [string]$Subdomain,
    
    [string]$Region = "ap-northeast-2"
)

$FullDomain = "$Subdomain.$Domain"

Write-Host "`n도메인 설정을 시작합니다..." -ForegroundColor Green
Write-Host "도메인: $Domain"
Write-Host "서브도메인: $Subdomain"
Write-Host "전체 도메인: $FullDomain"
Write-Host ""

# 1. Hosted Zone 확인
Write-Host "[1/6] Hosted Zone 확인 중..." -ForegroundColor Yellow
$hostedZones = aws route53 list-hosted-zones --query "HostedZones[?Name=='$Domain.'].Id" --output text 2>$null
$HostedZoneId = ($hostedZones -split '/')[2]

if ([string]::IsNullOrEmpty($HostedZoneId)) {
    Write-Host "Hosted Zone을 찾을 수 없습니다." -ForegroundColor Red
    Write-Host "다음 명령으로 Hosted Zone을 생성하세요:"
    Write-Host "aws route53 create-hosted-zone --name $Domain --caller-reference $(Get-Date -Format 'yyyyMMddHHmmss')"
    exit 1
}

Write-Host "✓ Hosted Zone ID: $HostedZoneId" -ForegroundColor Green
Write-Host ""

# 2. ACM 인증서 요청
Write-Host "[2/6] ACM 인증서 요청 중..." -ForegroundColor Yellow
$CertArn = aws acm request-certificate `
    --domain-name "$Domain" `
    --subject-alternative-names "*.$Domain" `
    --validation-method DNS `
    --region $Region `
    --query 'CertificateArn' `
    --output text 2>$null

if ([string]::IsNullOrEmpty($CertArn)) {
    Write-Host "기존 인증서를 확인하는 중..." -ForegroundColor Yellow
    $CertArn = (aws acm list-certificates `
        --region $Region `
        --query "CertificateSummaryList[?DomainName=='$Domain'].CertificateArn" `
        --output text | Select-Object -First 1)
    
    if ([string]::IsNullOrEmpty($CertArn)) {
        Write-Host "인증서 요청 실패" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ 기존 인증서 사용: $CertArn" -ForegroundColor Green
} else {
    Write-Host "✓ 인증서 ARN: $CertArn" -ForegroundColor Green
}
Write-Host ""

# 3. DNS 검증 레코드 정보 가져오기
Write-Host "[3/6] DNS 검증 레코드 확인 중..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

$validationRecord = aws acm describe-certificate `
    --certificate-arn "$CertArn" `
    --region $Region `
    --query 'Certificate.DomainValidationOptions[0].ResourceRecord' `
    --output json | ConvertFrom-Json

if ($validationRecord -and $validationRecord.Name) {
    $ValidationName = $validationRecord.Name
    $ValidationValue = $validationRecord.Value
    
    Write-Host "✓ 검증 레코드:" -ForegroundColor Green
    Write-Host "  Name: $ValidationName"
    Write-Host "  Value: $ValidationValue"
    
    # 4. DNS 검증 레코드 생성
    Write-Host "[4/6] DNS 검증 레코드 생성 중..." -ForegroundColor Yellow
    
    $changeBatch = @{
        Changes = @(
            @{
                Action = "UPSERT"
                ResourceRecordSet = @{
                    Name = $ValidationName
                    Type = "CNAME"
                    TTL = 300
                    ResourceRecords = @(
                        @{ Value = $ValidationValue }
                    )
                }
            }
        )
    } | ConvertTo-Json -Depth 10
    
    $changeBatch | Out-File -FilePath "$env:TEMP\acm-validation.json" -Encoding utf8
    
    aws route53 change-resource-record-sets `
        --hosted-zone-id $HostedZoneId `
        --change-batch "file://$env:TEMP\acm-validation.json" | Out-Null
    
    Write-Host "✓ DNS 검증 레코드 생성됨" -ForegroundColor Green
} else {
    Write-Host "⚠ DNS 검증 레코드가 아직 준비되지 않았습니다." -ForegroundColor Yellow
    Write-Host "AWS Console에서 수동으로 확인하세요:"
    Write-Host "https://console.aws.amazon.com/acm/home?region=$Region#/certificates/$CertArn"
}
Write-Host ""

# 5. 인증서 발급 대기
Write-Host "[5/6] 인증서 발급 대기 중... (최대 5분)" -ForegroundColor Yellow
$maxAttempts = 30
$Status = ""

for ($i = 1; $i -le $maxAttempts; $i++) {
    $Status = aws acm describe-certificate `
        --certificate-arn "$CertArn" `
        --region $Region `
        --query 'Certificate.Status' `
        --output text
    
    if ($Status -eq "ISSUED") {
        Write-Host "`n✓ 인증서 발급 완료!" -ForegroundColor Green
        break
    }
    
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 10
}
Write-Host ""

if ($Status -ne "ISSUED") {
    Write-Host "⚠ 인증서가 아직 발급되지 않았습니다. (현재 상태: $Status)" -ForegroundColor Yellow
    Write-Host "AWS Console에서 확인하세요:"
    Write-Host "https://console.aws.amazon.com/acm/home?region=$Region"
}
Write-Host ""

# 6. Ingress 설정 파일 업데이트
Write-Host "[6/6] Ingress 설정 파일 업데이트 중..." -ForegroundColor Yellow
$IngressFile = "k8s\ingress.yaml"

if (Test-Path $IngressFile) {
    # 백업 생성
    Copy-Item $IngressFile "$IngressFile.backup"
    
    # 파일 내용 읽기
    $content = Get-Content $IngressFile -Raw
    
    # 인증서 ARN 업데이트
    $content = $content -replace '# alb\.ingress\.kubernetes\.io/certificate-arn:.*', "alb.ingress.kubernetes.io/certificate-arn: $CertArn"
    $content = $content -replace 'alb\.ingress\.kubernetes\.io/certificate-arn:.*', "alb.ingress.kubernetes.io/certificate-arn: $CertArn"
    
    # 도메인 업데이트
    $content = $content -replace 'host:.*yourdomain.*', "host: $FullDomain"
    
    # 파일 저장
    $content | Set-Content $IngressFile -NoNewline
    
    Write-Host "✓ Ingress 설정 파일 업데이트 완료" -ForegroundColor Green
    Write-Host "  - 인증서 ARN: $CertArn"
    Write-Host "  - 도메인: $FullDomain"
} else {
    Write-Host "⚠ Ingress 파일을 찾을 수 없습니다: $IngressFile" -ForegroundColor Yellow
}
Write-Host ""

# 요약 출력
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "설정 완료!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "다음 정보를 기록하세요:"
Write-Host ""
Write-Host "도메인: $FullDomain"
Write-Host "Hosted Zone ID: $HostedZoneId"
Write-Host "인증서 ARN: $CertArn"
Write-Host "인증서 상태: $Status"
Write-Host ""
Write-Host "다음 단계:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Ingress 적용:"
Write-Host "   kubectl apply -f k8s\ingress.yaml"
Write-Host ""
Write-Host "2. ALB DNS 확인:"
Write-Host "   kubectl get ingress restful-web-services"
Write-Host ""
Write-Host "3. ALB DNS를 Route 53에 추가:"
Write-Host "   .\scripts\create-dns-record.ps1 -Domain '$Domain' -Subdomain '$Subdomain'"
Write-Host ""
Write-Host "4. DNS 전파 확인 (5-10분 소요):"
Write-Host "   nslookup $FullDomain"
Write-Host ""
Write-Host "5. HTTPS 접속 테스트:"
Write-Host "   curl https://$FullDomain/actuator/health"
Write-Host ""
