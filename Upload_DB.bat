@echo off
setlocal EnableDelayedExpansion
cls

:: ==========================================================
:: STEP 1 – SERVER SELECTION
:: ==========================================================
:server_menu
echo Select your server:
echo [1] 88.222.244.186
echo [2] 168.231.102.163
echo [3] Enter manually
echo.

set "SERVER_IP="
set /p SERVER_CHOICE="Enter your choice (1/2/3): "

if "%SERVER_CHOICE%"=="1" set "SERVER_IP=88.222.244.186"
if "%SERVER_CHOICE%"=="2" set "SERVER_IP=168.231.102.163"
if "%SERVER_CHOICE%"=="3" set /p SERVER_IP="Enter custom server IP: "

if not defined SERVER_IP goto server_menu

echo.
echo ----------------------------------------
echo.

:: ==========================================================
:: STEP 2 – SSH USER
:: ==========================================================
:username_prompt
set "SSH_USER="
set /p SSH_USER="Enter SSH username: "
if not defined SSH_USER goto username_prompt

echo.
echo ----------------------------------------
echo.

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
    echo No .sql or .sql.gz files found.
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
echo.

:: ==========================================================
:: STEP 4 – DB CREDENTIALS (HIDDEN PASSWORD)
:: ==========================================================
echo Enter MySQL Credentials:
echo.

set /p DB_USER="MySQL User: "

for /f "delims=" %%P in ('powershell -Command "$p=Read-Host \"MySQL Password\" -AsSecureString; $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($p); [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)"') do set DB_PASS=%%P

echo.
set /p TARGET_DB="Target Database Name: "
if not defined TARGET_DB (
    echo Database name required.
    pause
    exit
)

echo.
echo ----------------------------------------
echo.

:: ==========================================================
:: STEP 5 – UPLOAD FILE
:: ==========================================================
echo [Step 1/4] Uploading file...
scp "%SELECTED_FILE%" %SSH_USER%@%SERVER_IP%:/home/%SSH_USER%/temp_restore_file

if %ERRORLEVEL% NEQ 0 (
    echo Upload failed.
    pause
    exit
)

echo Upload successful.
echo.

:: ==========================================================
:: STEP 6 – CREATE DATABASE
:: ==========================================================
echo [Step 2/4] Creating database if not exists...

:: We use ANSI_QUOTES to avoid backtick issues which can cause the shell to hang
ssh %SSH_USER%@%SERVER_IP% "mysql -u!DB_USER! --password=\"!DB_PASS!\" -e \"SET sql_mode='ANSI_QUOTES'; CREATE DATABASE IF NOT EXISTS \\\"!TARGET_DB!\\\";\" 2>mysql_error.log"

if %ERRORLEVEL% NEQ 0 (
    echo Failed while creating database:
    ssh %SSH_USER%@%SERVER_IP% "cat mysql_error.log"
    goto cleanup
)

echo Database ready.
echo.

:: ==========================================================
:: STEP 7 – IMPORT DATABASE (LARGE FILE SAFE)
:: ==========================================================
echo [Step 3/4] Importing data...

set "REMOTE_SQL=/home/%SSH_USER%/temp_restore_file"

if /i "!SELECTED_FILE:~-3!"==".gz" (
    ssh %SSH_USER%@%SERVER_IP% "zcat %REMOTE_SQL% | mysql -u!DB_USER! --password=\"!DB_PASS!\" --max_allowed_packet=1G --net_buffer_length=1000000 \"!TARGET_DB!\" 2>>mysql_error.log"
) else (
    ssh %SSH_USER%@%SERVER_IP% "mysql -u!DB_USER! --password=\"!DB_PASS!\" --max_allowed_packet=1G --net_buffer_length=1000000 \"!TARGET_DB!\" < %REMOTE_SQL% 2>>mysql_error.log"
)

if %ERRORLEVEL% EQU 0 (
    echo.
    echo SUCCESS: Data imported successfully.
) else (
    echo.
    echo Import Failed. MySQL Error Details:
    echo ----------------------------------------
    ssh %SSH_USER%@%SERVER_IP% "cat mysql_error.log"
)

echo.

:: ==========================================================
:: STEP 8 – CLEANUP
:: ==========================================================
:cleanup
echo [Step 4/4] Cleaning temporary files...
ssh %SSH_USER%@%SERVER_IP% "rm -f /home/%SSH_USER%/temp_restore_file mysql_error.log"
echo Done.

echo.
echo ----------------------------------------
pause
endlocal