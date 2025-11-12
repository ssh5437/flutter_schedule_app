@echo off
chcp 65001 >nul
REM Edge Function Deploy Script

echo ========================================
echo Supabase Edge Function Deploy
echo ========================================
echo.

REM Menu
echo [1] Supabase Login
echo [2] Link Project (supabase link)
echo [3] Deploy Edge Function
echo [4] List Functions
echo [5] View Logs (Real-time)
echo [6] View Logs (Recent 20)
echo [0] Exit
echo.

set /p choice="Select (0-6): "

if "%choice%"=="1" goto login
if "%choice%"=="2" goto link
if "%choice%"=="3" goto deploy
if "%choice%"=="4" goto list
if "%choice%"=="5" goto logs_tail
if "%choice%"=="6" goto logs_recent
if "%choice%"=="0" goto end

:login
echo.
echo Starting Supabase login...
echo Please login in your browser.
echo.
supabase login
echo.
pause
goto end

:link
echo.
echo Linking to Supabase project...
echo Please select project in your browser.
echo.
supabase link
echo.
pause
goto end

:deploy
echo.
echo Deploying Edge Function...
echo.
supabase functions deploy verify-purchase
echo.
echo Deploy completed!
echo.
echo Next steps:
echo 1. Check Secrets in Supabase Dashboard
echo 2. View logs: Select [5] or [6] from menu
echo.
pause
goto end

:list
echo.
echo Deployed functions:
echo.
supabase functions list
echo.
pause
goto end

:logs_tail
echo.
echo Viewing Edge Function logs (real-time)...
echo Press CTRL+C to exit.
echo.
supabase functions logs verify-purchase --tail
goto end

:logs_recent
echo.
echo Recent 20 logs:
echo.
supabase functions logs verify-purchase --limit 20
echo.
pause
goto end

:end
echo.
echo Exiting...
