# PowerShell용 DNS 레코드 생성 스크립트
# 사용법: .\create-dns-record.ps1 -Domain "yourcompany.com" -Subdomain "api"

param(
    [Parameter(Mandatory=$true)]
    [string]$Domain,
    
    [Parameter(Mandatory=$true)]
    [string]$Subdomain
)

$FullDomain = "$Subdomain.$Domain"

Write-Host "`nDNS 레코드 생성을 시작합니다..." -ForegroundColor Green
Write-Host "도메인: $FullDomain"
Write-Host ""

# 1. Hosted Zone ID 확인
Write-Host "[1/4] Hosted Zone 확인 중..." -ForegroundColor Yellow
$hostedZones = aws route53 list-hosted-zones --query "HostedZones[?Name=='$Domain.'].Id" --output text
$HostedZoneId = ($hostedZones -split '/')[2]

if ([string]::IsNullOrEmpty($HostedZoneId)) {
    Write-Host "Hosted Zone을 찾을 수 없습니다: $Domain" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Hosted Zone ID: $HostedZoneId" -ForegroundColor Green
Write-Host ""

# 2. ALB DNS 이름 가져오기
Write-Host "[2/4] ALB DNS 이름 확인 중..." -ForegroundColor Yellow
$AlbDns = kubectl get ingress restful-web-services -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null

if ([string]::IsNullOrEmpty($AlbDns)) {
    Write-Host "Ingress에서 ALB를 찾을 수 없습니다." -ForegroundColor Red
    Write-Host "다음 명령으로 Ingress를 먼저 생성하세요:"
    Write-Host "kubectl apply -f k8s\ingress.yaml"
    exit 1
}

Write-Host "✓ ALB DNS: $AlbDns" -ForegroundColor Green
Write-Host ""

# 3. ALB Hosted Zone ID 확인 (리전별)
Write-Host "[3/4] ALB Hosted Zone ID 확인 중..." -ForegroundColor Yellow

$AlbHostedZoneId = ""
$Region = ""

if ($AlbDns -match "ap-northeast-2") {
    $AlbHostedZoneId = "Z3W03O7B5YMIYP"  # Seoul
    $Region = "ap-northeast-2"
} elseif ($AlbDns -match "us-east-1") {
    $AlbHostedZoneId = "Z35SXDOTRQ7X7K"  # N. Virginia
    $Region = "us-east-1"
} elseif ($AlbDns -match "ap-northeast-1") {
    $AlbHostedZoneId = "Z14GRHDCWA56QT"  # Tokyo
    $Region = "ap-northeast-1"
} else {
    Write-Host "알 수 없는 리전입니다." -ForegroundColor Red
    Write-Host "ALB DNS: $AlbDns"
    Write-Host "Hosted Zone ID를 수동으로 확인하세요:"
    Write-Host "https://docs.aws.amazon.com/general/latest/gr/elb.html"
    exit 1
}

Write-Host "✓ ALB Hosted Zone ID: $AlbHostedZoneId (Region: $Region)" -ForegroundColor Green
Write-Host ""

# 4. Route 53 레코드 생성
Write-Host "[4/4] Route 53 A 레코드 생성 중..." -ForegroundColor Yellow

$changeBatch = @{
    Changes = @(
        @{
            Action = "UPSERT"
            ResourceRecordSet = @{
                Name = $FullDomain
                Type = "A"
                AliasTarget = @{
                    HostedZoneId = $AlbHostedZoneId
                    DNSName = $AlbDns
                    EvaluateTargetHealth = $true
                }
            }
        }
    )
} | ConvertTo-Json -Depth 10

$changeBatch | Out-File -FilePath "$env:TEMP\route53-record.json" -Encoding utf8

$changeInfo = aws route53 change-resource-record-sets `
    --hosted-zone-id $HostedZoneId `
    --change-batch "file://$env:TEMP\route53-record.json" `
    --output json | ConvertFrom-Json

$ChangeId = $changeInfo.ChangeInfo.Id

Write-Host "✓ DNS 레코드 생성 요청 완료" -ForegroundColor Green
Write-Host "Change ID: $ChangeId"
Write-Host ""

# 5. 변경 상태 확인
Write-Host "DNS 변경 사항 전파 대기 중..." -ForegroundColor Yellow

for ($i = 1; $i -le 12; $i++) {
    $changeStatus = aws route53 get-change `
        --id $ChangeId `
        --query 'ChangeInfo.Status' `
        --output text
    
    if ($changeStatus -eq "INSYNC") {
        Write-Host "`n✓ DNS 변경 사항 전파 완료!" -ForegroundColor Green
        break
    }
    
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 5
}
Write-Host ""

# 6. DNS 확인
Write-Host "DNS 레코드 확인 중..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "Google DNS로 조회:"
nslookup $FullDomain 8.8.8.8

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "DNS 레코드 생성 완료!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "설정 정보:"
Write-Host "  도메인: $FullDomain"
Write-Host "  ALB DNS: $AlbDns"
Write-Host "  Hosted Zone ID: $HostedZoneId"
Write-Host ""
Write-Host "참고:" -ForegroundColor Yellow
Write-Host "- DNS 전파는 최대 48시간이 걸릴 수 있습니다."
Write-Host "- 보통 5-10분 내에 완료됩니다."
Write-Host ""
Write-Host "DNS 전파 확인:"
Write-Host "  nslookup $FullDomain"
Write-Host "  Resolve-DnsName $FullDomain"
Write-Host ""
Write-Host "온라인 도구:"
Write-Host "  https://dnschecker.org/#A/$FullDomain"
Write-Host "  https://www.whatsmydns.net/#A/$FullDomain"
Write-Host ""
Write-Host "HTTPS 접속 테스트:"
Write-Host "  curl https://$FullDomain/actuator/health"
Write-Host "  Invoke-WebRequest https://$FullDomain/helloworld"
Write-Host ""
