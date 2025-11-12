@echo off
chcp 65001 >nul
REM Edge Function Local Test Script

echo ========================================
echo Edge Function Local Test
echo ========================================
echo.

REM Menu
echo [1] Start Local Server
echo [2] Test - Missing Parameters
echo [3] Test - Invalid Token
echo [4] View Logs
echo [0] Exit
echo.

set /p choice="Select (0-4): "

if "%choice%"=="1" goto start_server
if "%choice%"=="2" goto test_missing_params
if "%choice%"=="3" goto test_invalid_token
if "%choice%"=="4" goto check_logs
if "%choice%"=="0" goto end

:start_server
echo.
echo Starting local Edge Function server...
echo Press CTRL+C to stop server.
echo.
supabase functions serve verify-purchase --env-file ./supabase/.env.local --no-verify-jwt
goto end

:test_missing_params
echo.
echo Test: Missing Parameters (Expected: 400 error)
echo.
curl -i --location --request POST "http://localhost:54321/functions/v1/verify-purchase" ^
  --header "Authorization: Bearer test-key" ^
  --header "Content-Type: application/json" ^
  --data "{\"productId\":\"bizplan_monthly_subscription\"}"
echo.
echo.
pause
goto end

:test_invalid_token
echo.
echo Test: Invalid Purchase Token (Expected: Google API error)
echo.
curl -i --location --request POST "http://localhost:54321/functions/v1/verify-purchase" ^
  --header "Authorization: Bearer test-key" ^
  --header "Content-Type: application/json" ^
  --data "{\"productId\":\"bizplan_monthly_subscription\",\"purchaseToken\":\"invalid-token-12345\",\"packageName\":\"com.vividlife.bizplan\"}"
echo.
echo.
pause
goto end

:check_logs
echo.
echo Checking Edge Function logs...
echo.
supabase functions logs verify-purchase --limit 20
echo.
pause
goto end

:end
echo.
echo Exiting...
