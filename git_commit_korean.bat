@echo off
chcp 65001 >nul
REM Git Commit with Korean Support

if "%~1"=="" (
    echo Usage: git_commit_korean.bat "commit message"
    echo Example: git_commit_korean.bat "디버그 화면 수정"
    exit /b 1
)

git add .
git commit -m "%~1"

echo.
echo Commit completed!
git log -1 --oneline
