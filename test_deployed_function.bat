@echo off
chcp 65001 >nul
REM Test Deployed Edge Function

set SUPABASE_URL=https://bsofmuvuvhjpcrkygwjz.supabase.co
set SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzb2ZtdXZ1dmhqcGNya3lnd2p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjY0ODksImV4cCI6MjA3NjM0MjQ4OX0.fdpNtooV0rPmdnZz2RSCuBxMeQEPuvjJTTXTIzaKZhQ

echo ========================================
echo Test Deployed Edge Function
echo ========================================
echo.
echo Supabase URL: %SUPABASE_URL%
echo.

REM Menu
echo [1] Test - Missing Parameters (Expected: 400 error)
echo [2] Test - Invalid Token (Expected: Google API error)
echo [3] Test - Missing Package Name (Expected: 400 error)
echo [4] Open Supabase Dashboard - Edge Functions
echo [5] Open Supabase Dashboard - Logs
echo [0] Exit
echo.

set /p choice="Select (0-5): "

if "%choice%"=="1" goto test_missing_params
if "%choice%"=="2" goto test_invalid_token
if "%choice%"=="3" goto test_missing_package
if "%choice%"=="4" goto open_functions
if "%choice%"=="5" goto open_logs
if "%choice%"=="0" goto end

:test_missing_params
echo.
echo Test: Missing Parameters
echo Expected: HTTP 400 - "Missing required parameters"
echo.
curl -i --location --request POST "%SUPABASE_URL%/functions/v1/verify-purchase" ^
  --header "Authorization: Bearer %SUPABASE_ANON_KEY%" ^
  --header "Content-Type: application/json" ^
  --data "{\"productId\":\"bizplan_monthly_subscription\"}"
echo.
echo.
echo Now check the logs in Supabase Dashboard!
echo.
pause
goto end

:test_invalid_token
echo.
echo Test: Invalid Purchase Token
echo Expected: HTTP 400 - Google API error
echo.
curl -i --location --request POST "%SUPABASE_URL%/functions/v1/verify-purchase" ^
  --header "Authorization: Bearer %SUPABASE_ANON_KEY%" ^
  --header "Content-Type: application/json" ^
  --data "{\"productId\":\"bizplan_monthly_subscription\",\"purchaseToken\":\"invalid-token-12345\",\"packageName\":\"com.vividlife.bizplan\"}"
echo.
echo.
echo Now check the logs in Supabase Dashboard!
echo.
pause
goto end

:test_missing_package
echo.
echo Test: Missing Package Name
echo Expected: HTTP 400 - "Missing required parameters"
echo.
curl -i --location --request POST "%SUPABASE_URL%/functions/v1/verify-purchase" ^
  --header "Authorization: Bearer %SUPABASE_ANON_KEY%" ^
  --header "Content-Type: application/json" ^
  --data "{\"productId\":\"bizplan_monthly_subscription\",\"purchaseToken\":\"test-token\"}"
echo.
echo.
echo Now check the logs in Supabase Dashboard!
echo.
pause
goto end

:open_functions
echo.
echo Opening Supabase Dashboard - Edge Functions...
start https://supabase.com/dashboard/project/bsofmuvuvhjpcrkygwjz/functions
goto end

:open_logs
echo.
echo Opening Supabase Dashboard - Logs...
start https://supabase.com/dashboard/project/bsofmuvuvhjpcrkygwjz/logs/edge-functions
goto end

:end
echo.
echo Exiting...
