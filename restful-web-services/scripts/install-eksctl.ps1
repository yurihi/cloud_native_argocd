# eksctl 직접 설치 스크립트 (관리자 권한 불필요)

# PowerShell에서 실행
# 이 스크립트는 eksctl을 다운로드하고 사용자 경로에 설치합니다

$ErrorActionPreference = "Stop"

Write-Host "eksctl 설치를 시작합니다..." -ForegroundColor Green
Write-Host ""

# 1. 설치 디렉토리 생성
$installPath = "$env:USERPROFILE\bin"
if (!(Test-Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath | Out-Null
    Write-Host "✓ 설치 디렉토리 생성: $installPath" -ForegroundColor Green
}

# 2. 최신 버전 확인
Write-Host "최신 버전 확인 중..." -ForegroundColor Yellow
$latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/eksctl-io/eksctl/releases/latest"
$version = $latestRelease.tag_name
$downloadUrl = "https://github.com/eksctl-io/eksctl/releases/download/$version/eksctl_Windows_amd64.zip"

Write-Host "✓ 최신 버전: $version" -ForegroundColor Green
Write-Host ""

# 3. 다운로드
$tempFile = "$env:TEMP\eksctl.zip"
Write-Host "다운로드 중: $downloadUrl" -ForegroundColor Yellow
Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing
Write-Host "✓ 다운로드 완료" -ForegroundColor Green
Write-Host ""

# 4. 압축 해제
Write-Host "압축 해제 중..." -ForegroundColor Yellow
Expand-Archive -Path $tempFile -DestinationPath $installPath -Force
Write-Host "✓ 압축 해제 완료" -ForegroundColor Green
Write-Host ""

# 5. PATH 환경 변수에 추가
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$installPath*") {
    Write-Host "PATH 환경 변수에 추가 중..." -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$installPath", "User")
    $env:Path = "$env:Path;$installPath"
    Write-Host "✓ PATH 환경 변수 업데이트 완료" -ForegroundColor Green
} else {
    Write-Host "✓ PATH 환경 변수에 이미 등록되어 있습니다" -ForegroundColor Green
}
Write-Host ""

# 6. 임시 파일 삭제
Remove-Item $tempFile -Force
Write-Host "✓ 임시 파일 삭제 완료" -ForegroundColor Green
Write-Host ""

# 7. 설치 확인
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "eksctl 설치 완료!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "설치 경로: $installPath\eksctl.exe" -ForegroundColor Cyan
Write-Host "버전: $version" -ForegroundColor Cyan
Write-Host ""
Write-Host "다음 명령어로 확인하세요:" -ForegroundColor Yellow
Write-Host "  eksctl version" -ForegroundColor White
Write-Host ""
Write-Host "참고: 새 PowerShell 창에서 실행해야 할 수 있습니다." -ForegroundColor Yellow
Write-Host ""

# 현재 세션에서 바로 확인
try {
    $eksctlPath = Join-Path $installPath "eksctl.exe"
    if (Test-Path $eksctlPath) {
        Write-Host "현재 세션에서 버전 확인:" -ForegroundColor Cyan
        & $eksctlPath version
    }
} catch {
    Write-Host "새 PowerShell 창을 열어서 'eksctl version' 명령어를 실행하세요." -ForegroundColor Yellow
}
