@echo off
chcp 65001 >nul
REM Check Google API Authentication Status

set SUPABASE_URL=https://bsofmuvuvhjpcrkygwjz.supabase.co
set SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJzb2ZtdXZ1dmhqcGNya3lnd2p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjY0ODksImV4cCI6MjA3NjM0MjQ4OX0.fdpNtooV0rPmdnZz2RSCuBxMeQEPuvjJTTXTIzaKZhQ

echo ========================================
echo Google API Authentication Check
echo ========================================
echo.
echo Testing if Supabase Secrets are configured...
echo.

curl -s "%SUPABASE_URL%/functions/v1/verify-purchase" ^
  -H "Authorization: Bearer %SUPABASE_ANON_KEY%" ^
  -H "Content-Type: application/json" ^
  -d "{\"productId\":\"bizplan_monthly_subscription\",\"purchaseToken\":\"test-token\",\"packageName\":\"com.vividlife.bizplan\"}" > temp_result.txt

echo Response:
type temp_result.txt
echo.
echo.

findstr /C:"UNAUTHENTICATED" temp_result.txt >nul
if %errorlevel% == 0 (
    echo [FAIL] Google API Authentication Failed
    echo.
    echo Problem: Supabase Secrets are NOT configured correctly.
    echo.
    echo Solution:
    echo 1. Go to: https://supabase.com/dashboard/project/bsofmuvuvhjpcrkygwjz/settings/functions
    echo 2. Add these Secrets:
    echo    - GOOGLE_SERVICE_ACCOUNT_EMAIL
    echo    - GOOGLE_PRIVATE_KEY
    echo 3. Run this script again
    echo.
) else (
    findstr /C:"Invalid Credentials" temp_result.txt >nul
    if %errorlevel% == 0 (
        echo [FAIL] Google API Authentication Failed
        echo.
        echo Problem: Secrets might be incorrect or service account key expired.
        echo.
        echo Solution:
        echo 1. Download new service account key from Google Cloud Console
        echo 2. Update GOOGLE_PRIVATE_KEY in Supabase Secrets
        echo 3. Run this script again
        echo.
    ) else (
        findstr /C:"authError" temp_result.txt >nul
        if %errorlevel% == 0 (
            echo [FAIL] Google Service Account Permission Issue
            echo.
            echo Problem: Service account needs permissions in Google Play Console.
            echo.
            echo Solution:
            echo 1. Go to Google Play Console - Users and permissions
            echo 2. Invite: bizplan-purchase-verifier@bizplan-478009.iam.gserviceaccount.com
            echo 3. Grant "View financial data" permission
            echo.
        ) else (
            echo [PASS] Google API Authentication Working!
            echo.
            echo The error "Purchase token not found" or "Purchase verification failed"
            echo is EXPECTED because we used a test token.
            echo.
            echo Next steps:
            echo 1. Create subscription product in Google Play Console
            echo 2. Add test account
            echo 3. Test real purchase from Flutter app
            echo.
        )
    )
)

del temp_result.txt 2>nul

echo.
echo See GOOGLE_PLAY_SETUP_CHECKLIST.md for detailed instructions.
echo.
pause
