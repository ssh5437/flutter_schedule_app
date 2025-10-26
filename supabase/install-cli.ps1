# Supabase CLI 설치 스크립트 (Windows)
# PowerShell 관리자 권한으로 실행

Write-Host "Supabase CLI 설치 시작..." -ForegroundColor Green

# Scoop이 설치되어 있는지 확인
if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "`n1. Scoop 패키지 매니저 설치 중..." -ForegroundColor Yellow

    # ExecutionPolicy 설정
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

    # Scoop 설치
    try {
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        Write-Host "✓ Scoop 설치 완료!" -ForegroundColor Green
    } catch {
        Write-Host "✗ Scoop 설치 실패. 수동으로 설치해주세요." -ForegroundColor Red
        Write-Host "방법: https://scoop.sh" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "✓ Scoop이 이미 설치되어 있습니다." -ForegroundColor Green
}

# Supabase bucket 추가
Write-Host "`n2. Supabase bucket 추가 중..." -ForegroundColor Yellow
try {
    scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
    Write-Host "✓ Supabase bucket 추가 완료!" -ForegroundColor Green
} catch {
    Write-Host "! Bucket이 이미 추가되어 있거나 추가 중 오류 발생" -ForegroundColor Yellow
}

# Supabase CLI 설치
Write-Host "`n3. Supabase CLI 설치 중..." -ForegroundColor Yellow
try {
    scoop install supabase
    Write-Host "✓ Supabase CLI 설치 완료!" -ForegroundColor Green
} catch {
    Write-Host "✗ Supabase CLI 설치 실패" -ForegroundColor Red
    exit 1
}

# 설치 확인
Write-Host "`n4. 설치 확인 중..." -ForegroundColor Yellow
$version = supabase --version
if ($version) {
    Write-Host "✓ Supabase CLI가 성공적으로 설치되었습니다!" -ForegroundColor Green
    Write-Host "버전: $version" -ForegroundColor Cyan

    Write-Host "`n다음 단계:" -ForegroundColor Yellow
    Write-Host "1. supabase login" -ForegroundColor White
    Write-Host "2. supabase link --project-ref <YOUR_PROJECT_REF>" -ForegroundColor White
    Write-Host "3. supabase secrets set GEMINI_API_KEY=<YOUR_API_KEY>" -ForegroundColor White
    Write-Host "4. supabase functions deploy extract-schedule" -ForegroundColor White
} else {
    Write-Host "✗ 설치 확인 실패" -ForegroundColor Red
    exit 1
}
