@echo off
setlocal EnableDelayedExpansion
cls

:: ==========================================================
:: STEP 1 – SERVER SELECTION
:: ==========================================================
:server_menu
echo Select your server:
echo [1] Free server
echo [2] Paid server
echo [3] Enter manually
echo.

set "SERVER_IP="
set /p SERVER_CHOICE="Enter your choice (1/2/3): "

if "%SERVER_CHOICE%"=="1" (
    set /p SERVER_IP="Enter Free server IP or domain: "
) else if "%SERVER_CHOICE%"=="2" (
    set /p SERVER_IP="Enter Paid server IP or domain: "
) else if "%SERVER_CHOICE%"=="3" (
    set /p SERVER_IP="Enter custom server IP: "
)

if not defined SERVER_IP goto server_menu

echo.
echo ----------------------------------------

:: ==========================================================
:: STEP 2 – SSH USER
:: ==========================================================
:username_prompt
set "SSH_USER="
set /p SSH_USER="Enter SSH username: "
if not defined SSH_USER goto username_prompt

echo.
echo ----------------------------------------

:: ==========================================================
:: STEP 3 – FILE SELECTION
:: ==========================================================
:file_menu
echo Select the SQL file to Upload:
echo.

set "FILE_COUNT=0"
for %%F in (*.sql *.sql.gz) do (
    set /a FILE_COUNT+=1
    set "FILE[!FILE_COUNT!]=%%F"
    echo [!FILE_COUNT!] %%F
)

if %FILE_COUNT% EQU 0 (
    echo No .sql or .sql.gz files found in current directory.
    pause
    exit
)

echo.
set /p FILE_CHOICE="Enter file number: "

if %FILE_CHOICE% GTR 0 if %FILE_CHOICE% LEQ %FILE_COUNT% (
    set "SELECTED_FILE=!FILE[%FILE_CHOICE%]!"
) else (
    echo Invalid choice.
    goto file_menu
)

echo.
echo ----------------------------------------

:: ==========================================================
:: STEP 4 – DB CREDENTIALS
:: ==========================================================
echo Enter MySQL Credentials:
echo.

set /p DB_USER="MySQL User: "

:: Secure password input via PowerShell
for /f "delims=" %%P in ('powershell -Command "$p=Read-Host \"MySQL Password\" -AsSecureString; $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($p); [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)"') do set "DB_PASS=%%P"

echo.
set /p TARGET_DB="Target Database Name: "
if not defined TARGET_DB (
    echo Database name required.
    pause
    exit
)

echo.
echo ----------------------------------------

:: ==========================================================
:: STEP 5 – UPLOAD FILE
:: ==========================================================
echo [Step 1/4] Uploading file...
scp "%SELECTED_FILE%" %SSH_USER%@%SERVER_IP%:/home/%SSH_USER%/temp_restore_file

if %ERRORLEVEL% NEQ 0 (
    echo Upload failed. Check SSH credentials or network.
    pause
    exit
)

echo Upload successful.
echo.

:: ==========================================================
:: STEP 5.5 – CREATE TEMP CONFIG (FIXES AUTH ISSUES)
:: ==========================================================
:: We create a temporary .my.cnf file on the server to hold credentials securely
echo [Step 1.5/4] Configuring remote authentication...
ssh %SSH_USER%@%SERVER_IP% "printf \"[client]\nuser=%DB_USER%\npassword='%DB_PASS%'\" > ~/.my.cnf_tmp && chmod 600 ~/.my.cnf_tmp"

:: ==========================================================
:: STEP 6 – CREATE DATABASE
:: ==========================================================
echo [Step 2/4] Creating database if not exists...

ssh %SSH_USER%@%SERVER_IP% "mysql --defaults-extra-file=~/.my.cnf_tmp -e \"CREATE DATABASE IF NOT EXISTS \`%TARGET_DB%\`;\" 2>mysql_error.log"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Could not access MySQL. 
    echo If using 'root', ensure the server allows password login for root,
    echo or use a dedicated database user instead.
    echo.
    ssh %SSH_USER%@%SERVER_IP% "cat mysql_error.log"
    goto cleanup
)

echo Database ready.
echo.

:: ==========================================================
:: STEP 7 – IMPORT DATABASE
:: ==========================================================
echo [Step 3/4] Importing data (this may take time)...

set "REMOTE_SQL=/home/%SSH_USER%/temp_restore_file"

if /i "!SELECTED_FILE:~-3!"==".gz" (
    ssh %SSH_USER%@%SERVER_IP% "zcat %REMOTE_SQL% | mysql --defaults-extra-file=~/.my.cnf_tmp --max_allowed_packet=1G \"%TARGET_DB%\" 2>>mysql_error.log"
) else (
    ssh %SSH_USER%@%SERVER_IP% "mysql --defaults-extra-file=~/.my.cnf_tmp --max_allowed_packet=1G \"%TARGET_DB%\" < %REMOTE_SQL% 2>>mysql_error.log"
)

if %ERRORLEVEL% EQU 0 (
    echo SUCCESS: Data imported successfully.
) else (
    echo.
    echo Import Failed. MySQL Error Details:
    echo ----------------------------------------
    ssh %SSH_USER%@%SERVER_IP% "cat mysql_error.log"
)

:: ==========================================================
:: STEP 8 – CLEANUP
:: ==========================================================
:cleanup
echo.
echo [Step 4/4] Cleaning temporary files...
ssh %SSH_USER%@%SERVER_IP% "rm -f /home/%SSH_USER%/temp_restore_file mysql_error.log ~/.my.cnf_tmp"
echo Done.

echo ----------------------------------------
pause
endlocal
