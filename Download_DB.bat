@echo off
setlocal EnableDelayedExpansion

cls

:server_menu
echo Select your server:
echo [1] 88.222.244.186  (Free)
echo [2] 168.231.102.163 (Paid)
echo [3] Enter manually
echo.
set "SERVER_CHOICE="
set /p SERVER_CHOICE="Enter your choice (1/2/3): "
if "%SERVER_CHOICE%"=="1" set "SERVER_IP=88.222.244.186"
if "%SERVER_CHOICE%"=="2" set "SERVER_IP=168.231.102.163"
if "%SERVER_CHOICE%"=="3" (set "SERVER_IP=" & set /p SERVER_IP="Enter custom server IP or domain: ")
if not defined SERVER_IP (echo Invalid choice. & goto server_menu)

echo. & echo ---------------------------------------- & echo.

:username_prompt
set "SSH_USER="
set /p SSH_USER="Enter SSH username (e.g. SSH User Name): "
if not defined SSH_USER (echo Username cannot be empty. & goto username_prompt)

echo. & echo ---------------------------------------- & echo.

:db_credentials
echo Enter MySQL Credentials for the dump:
echo.
set "DB_USER="
set /p DB_USER="MySQL User (e.g. Database User Name): "
set "DB_PASS="
set /p DB_PASS="MySQL Password: "

echo. & echo ---------------------------------------- & echo.
echo Fetching database list...
echo (Note: Run 'ssh-add' in terminal to avoid password prompts)
echo.

:database_menu
echo Select a database to backup:
set "DB_COUNT=0"

REM Hum database list fetch karne ki koshish karenge using credentials
set "CMD_LIST_DB=mysql -u%DB_USER% -p'%DB_PASS%' -e 'SHOW DATABASES;' | grep -Ev 'Database|information_schema|performance_schema|mysql|sys'"

for /f "tokens=*" %%A in ('ssh -o "StrictHostKeyChecking=no" %SSH_USER%@%SERVER_IP% "%CMD_LIST_DB%"') do (
    set /a DB_COUNT+=1
    set "DB_NAME=%%A"
    set "DB[!DB_COUNT!]=!DB_NAME!"
    echo [!DB_COUNT!] !DB_NAME!
)

if %DB_COUNT% EQU 0 (
    echo Could not list databases automatically.
    echo Please enter the Database Name manually.
    echo.
    set /p MANUAL_DB="Enter Database Name: "
    set "SELECTED_DB=!MANUAL_DB!"
    set "SQL_FILE_NAME=!MANUAL_DB!.sql"
    goto check_existing
)

echo.
set "DB_CHOICE="
set /p DB_CHOICE="Enter the number of the database: "

if not defined DB_CHOICE (echo. & echo No selection made. & goto database_menu)
if %DB_CHOICE% GTR 0 if %DB_CHOICE% LEQ %DB_COUNT% (
    set "SELECTED_DB=!DB[%DB_CHOICE%]!"
    set "SQL_FILE_NAME=!SELECTED_DB!.sql"
) else (
    echo. & echo Invalid number. & goto database_menu
)

:check_existing
echo. & echo ---------------------------------------- & echo.

REM Checking file existence in htdocs
ssh -o ServerAliveInterval=30 %SSH_USER%@%SERVER_IP% "test -f /home/%SSH_USER%/htdocs/!SQL_FILE_NAME!" >nul 2>nul
set "FILE_EXISTS_CHECK=%ERRORLEVEL%"
set "SHOULD_CREATE_DUMP=0"

if %FILE_EXISTS_CHECK% EQU 0 (
    :overwrite_prompt
    echo SERVER WARNING: "!SQL_FILE_NAME!" already exists on the server.
    set "OVERWRITE_CHOICE="
    set /p OVERWRITE_CHOICE="Overwrite (Y), download existing (N), or create with new name (R)? (Y/N/R): "
    
    set "VALID_INPUT=0"
    if /i "%OVERWRITE_CHOICE%"=="Y" ( set "SHOULD_CREATE_DUMP=1" & set "VALID_INPUT=1" )
    if /i "%OVERWRITE_CHOICE%"=="N" ( set "SHOULD_CREATE_DUMP=0" & set "VALID_INPUT=1" )
    if /i "%OVERWRITE_CHOICE%"=="R" (
        set "VALID_INPUT=1"
        :new_remote_name
        echo.
        set "NEW_NAME="
        set /p NEW_NAME="Enter new filename for server (e.g. backup.sql): "
        if not defined NEW_NAME (echo Name cannot be empty. & goto new_remote_name)
        if /i not "!NEW_NAME:~-4!"==".sql" set "NEW_NAME=!NEW_NAME!.sql"
        set "SQL_FILE_NAME=!NEW_NAME!"
        set "SHOULD_CREATE_DUMP=1"
    )
    if "%VALID_INPUT%"=="0" ( echo Invalid input. Please enter Y, N, or R. & echo. & goto :overwrite_prompt )
) else (
    set "SHOULD_CREATE_DUMP=1"
)

if %SHOULD_CREATE_DUMP% EQU 1 (
    echo.
    echo Generating database backup "!SQL_FILE_NAME!"...
    echo (Using optimized settings: single-transaction, skip-lock-tables...)
    
    REM === THIS IS YOUR VERIFIED COMMAND ===
    REM We cd into htdocs first so the file saves there
    set "DUMP_CMD=cd /home/%SSH_USER%/htdocs/ && mysqldump -u%DB_USER% -p'%DB_PASS%' --single-transaction --skip-lock-tables --skip-add-locks --set-gtid-purged=OFF --no-tablespaces !SELECTED_DB! > !SQL_FILE_NAME!"
    
    ssh -o "ServerAliveInterval=30" -o "ServerAliveCountMax=240" %SSH_USER%@%SERVER_IP% "!DUMP_CMD!"
    
    if %ERRORLEVEL% NEQ 0 (echo. & echo Failed to create database dump. Check User/Password. & goto end)
    echo.
    echo Database backup created successfully.
)

echo. & echo ---------------------------------------- & echo.

set "LOCAL_SAVE_NAME=!SQL_FILE_NAME!"
if exist "!SQL_FILE_NAME!" (
    :local_overwrite_prompt
    echo LOCAL WARNING: The file "!SQL_FILE_NAME!" already exists in this folder.
    set "LOCAL_OVERWRITE_CHOICE="
    set /p LOCAL_OVERWRITE_CHOICE="Overwrite local file (Y), cancel (N), or save with new name (R)? (Y/N/R): "

    set "VALID_LOCAL_INPUT=0"
    if /i "%LOCAL_OVERWRITE_CHOICE%"=="Y" ( set "VALID_LOCAL_INPUT=1" )
    if /i "%LOCAL_OVERWRITE_CHOICE%"=="N" ( echo. & echo Download cancelled by user. & goto end )
    if /i "%LOCAL_OVERWRITE_CHOICE%"=="R" (
        set "VALID_LOCAL_INPUT=1"
        :new_local_name
        echo.
        set "NEW_LOCAL_NAME="
        set /p NEW_LOCAL_NAME="Enter new local file name to save as: "
        if not defined NEW_LOCAL_NAME (echo Name cannot be empty. & goto new_local_name)
        if /i not "!NEW_LOCAL_NAME:~-4!"==".sql" set "NEW_LOCAL_NAME=!NEW_LOCAL_NAME!.sql"
        set "LOCAL_SAVE_NAME=!NEW_LOCAL_NAME!"
    )
    if "%VALID_LOCAL_INPUT%"=="0" ( echo Invalid input. Please enter Y, N, or R. & echo. & goto :local_overwrite_prompt )
)

echo.
echo Starting download of "!SQL_FILE_NAME!"...
scp -o "ServerAliveInterval=30" %SSH_USER%@%SERVER_IP%:/home/%SSH_USER%/htdocs/"!SQL_FILE_NAME!" "!LOCAL_SAVE_NAME!"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Download successful!
    
    echo.
    set /p DEL_REMOTE="Delete remote file from server to save space? (Y/N): "
    if /i "!DEL_REMOTE!"=="Y" (
        ssh %SSH_USER%@%SERVER_IP% "rm /home/%SSH_USER%/htdocs/!SQL_FILE_NAME!"
        echo Remote file deleted.
    )
) else (
    echo.
    echo Download failed!
)

:end
echo. & echo ----------------------------------------
pause
endlocal