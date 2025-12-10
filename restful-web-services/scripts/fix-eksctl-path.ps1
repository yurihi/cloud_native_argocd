# eksctl PATH 설정 스크립트
# 현재 PowerShell 세션에서 eksctl을 바로 사용할 수 있도록 설정

Write-Host "eksctl PATH 설정 중..." -ForegroundColor Yellow
Write-Host ""

# 1. 설치 확인
$eksctlPath = "$env:USERPROFILE\bin\eksctl.exe"

if (Test-Path $eksctlPath) {
    Write-Host "✓ eksctl 설치 확인: $eksctlPath" -ForegroundColor Green
} else {
    Write-Host "✗ eksctl이 설치되어 있지 않습니다." -ForegroundColor Red
    Write-Host "다음 스크립트를 먼저 실행하세요:" -ForegroundColor Yellow
    Write-Host "  .\scripts\install-eksctl.ps1" -ForegroundColor White
    exit 1
}

# 2. 현재 세션 PATH에 추가
$binPath = "$env:USERPROFILE\bin"
if ($env:Path -notlike "*$binPath*") {
    $env:Path += ";$binPath"
    Write-Host "✓ 현재 세션 PATH에 추가됨" -ForegroundColor Green
} else {
    Write-Host "✓ 현재 세션 PATH에 이미 등록됨" -ForegroundColor Green
}

# 3. 사용자 환경 변수 확인
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$binPath*") {
    Write-Host "⚠ 사용자 환경 변수에 미등록" -ForegroundColor Yellow
    Write-Host "  영구 등록하려면 install-eksctl.ps1을 다시 실행하세요" -ForegroundColor Yellow
} else {
    Write-Host "✓ 사용자 환경 변수에 등록됨" -ForegroundColor Green
}

Write-Host ""

# 4. 버전 확인
Write-Host "eksctl 버전 확인:" -ForegroundColor Cyan
try {
    & $eksctlPath version
    Write-Host ""
    Write-Host "✓ eksctl이 정상 작동합니다!" -ForegroundColor Green
} catch {
    Write-Host "✗ eksctl 실행 실패" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host ""
Write-Host "이제 'eksctl' 명령어를 사용할 수 있습니다." -ForegroundColor Green
Write-Host ""
Write-Host "테스트:" -ForegroundColor Cyan
Write-Host "  eksctl version" -ForegroundColor White
Write-Host "  eksctl get cluster --region ap-northeast-2" -ForegroundColor White
Write-Host ""
