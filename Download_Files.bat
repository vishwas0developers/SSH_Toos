@echo off
setlocal EnableDelayedExpansion

cls

:server_menu
echo Select your server:
echo [1] 990.990.990.990
echo [2] 990.990.990.990
echo [3] Enter manually
echo.
set "SERVER_CHOICE="
set /p SERVER_CHOICE="Enter your choice (1/2/3): "
if "%SERVER_CHOICE%"=="1" set "SERVER_IP=990.990.990.990"
if "%SERVER_CHOICE%"=="2" set "SERVER_IP=990.990.990.990"
if "%SERVER_CHOICE%"=="3" (set "SERVER_IP=" & set /p SERVER_IP="Enter custom server IP or domain: ")
if not defined SERVER_IP (echo Invalid choice. & goto server_menu)

echo. & echo ---------------------------------------- & echo.

:username_prompt
set "SSH_USER="
set /p SSH_USER="Enter SSH username (e.g. admin_ssh): "
if not defined SSH_USER (echo Username cannot be empty. & goto username_prompt)

echo. & echo ---------------------------------------- & echo.
echo Fetching directory list from server...
echo (Note: Run 'ssh-add' in your terminal first to avoid passphrase prompts)
echo.

:directory_menu
echo Select a directory to zip and download:
set "DIR_COUNT=0"
REM Removed ServerAliveInterval here to fix the syntax error (listing is fast anyway)
for /f "tokens=*" %%A in ('ssh -o "StrictHostKeyChecking=no" %SSH_USER%@%SERVER_IP% "cd /home/%SSH_USER%/htdocs/ && ls -d */ 2>/dev/null"') do (
    set /a DIR_COUNT+=1
    set "DIR_NAME=%%A"
    set "CLEAN_DIR_NAME=!DIR_NAME:~0,-1!"
    set "DIR[!DIR_COUNT!]=!CLEAN_DIR_NAME!"
    echo [!DIR_COUNT!] !CLEAN_DIR_NAME!
)
if %DIR_COUNT% EQU 0 (echo. & echo No directories found or connection failed. & goto end)
echo.
set "DIR_CHOICE="
set /p DIR_CHOICE="Enter the number of the directory: "
if not defined DIR_CHOICE (echo. & echo No selection made. & goto directory_menu)
if %DIR_CHOICE% GTR 0 if %DIR_CHOICE% LEQ %DIR_COUNT% (
    set "SELECTED_DIR=!DIR[%DIR_CHOICE%]!"
    set "ZIP_FILE_NAME=!SELECTED_DIR!.zip"
) else (
    echo. & echo Invalid number. & goto directory_menu
)

echo. & echo ---------------------------------------- & echo.

REM Checking file existence
ssh -o ServerAliveInterval=30 %SSH_USER%@%SERVER_IP% "test -f /home/%SSH_USER%/htdocs/!ZIP_FILE_NAME!" >nul 2>nul
set "FILE_EXISTS_CHECK=%ERRORLEVEL%"
set "SHOULD_CREATE_ZIP=0"

if %FILE_EXISTS_CHECK% NEQ 0 (
    set "SHOULD_CREATE_ZIP=1"
    goto after_overwrite
)

:overwrite_prompt
echo SERVER WARNING: "!ZIP_FILE_NAME!" already exists on the server.
set "OVERWRITE_CHOICE="
set /p OVERWRITE_CHOICE="Overwrite (Y), download existing (N), or create with new name (R)? (Y/N/R): "
if /i "!OVERWRITE_CHOICE!"=="Y" (set "SHOULD_CREATE_ZIP=1" & goto after_overwrite)
if /i "!OVERWRITE_CHOICE!"=="N" (set "SHOULD_CREATE_ZIP=0" & goto after_overwrite)
if /i "!OVERWRITE_CHOICE!"=="R" goto new_remote_name
echo Invalid input. Please enter Y, N, or R. & echo.
goto overwrite_prompt

:new_remote_name
echo.
set "NEW_NAME="
set /p NEW_NAME="Enter new zip file name for server (e.g., backup.zip): "
if not defined NEW_NAME (echo Name cannot be empty. & goto new_remote_name)
if /i not "!NEW_NAME:~-4!"==".zip" set "NEW_NAME=!NEW_NAME!.zip"
set "ZIP_FILE_NAME=!NEW_NAME!"
set "SHOULD_CREATE_ZIP=1"

:after_overwrite
if %SHOULD_CREATE_ZIP% NEQ 1 goto skip_zip

:zip_mode_prompt
echo Select what to include in the ZIP archive:
echo [1] Include ALL files (ignore .gitignore - archive everything)
echo [2] Exclude Git-ignored files (only files not ignored by Git)
echo.
set "ZIP_MODE="
set /p ZIP_MODE="Enter your choice (1/2): "
if not "%ZIP_MODE%"=="1" if not "%ZIP_MODE%"=="2" (echo. & echo Invalid choice. Please enter 1 or 2. & echo. & goto zip_mode_prompt)

echo.
echo Creating "!ZIP_FILE_NAME!" on the server...
echo (Showing progress to keep connection alive. Please wait...)

REM SOLUTION APPLIED HERE:
REM 1. Added -o "ServerAliveInterval=30" to prevent timeout
REM 2. Removed -q from zip command to show file progress
if "%ZIP_MODE%"=="1" (
    REM Mode 1: Include ALL files regardless of .gitignore
    ssh -o "ServerAliveInterval=30" -o "ServerAliveCountMax=240" %SSH_USER%@%SERVER_IP% "cd /home/%SSH_USER%/htdocs/ && rm -f !ZIP_FILE_NAME! && zip -r !ZIP_FILE_NAME! !SELECTED_DIR!"
) else (
    REM Mode 2: Exclude Git-ignored files and directories
    ssh -o "ServerAliveInterval=30" -o "ServerAliveCountMax=240" %SSH_USER%@%SERVER_IP% "cd /home/%SSH_USER%/htdocs/ && rm -f !ZIP_FILE_NAME! && TEMP_GIT=0 && if [ -d !SELECTED_DIR!/.git ]; then :; else git -c safe.directory=* -C !SELECTED_DIR! init >/dev/null 2>&1 && TEMP_GIT=1; fi && git -c safe.directory=* -C !SELECTED_DIR! ls-files -co --exclude-standard | sed s#^^#!SELECTED_DIR!/# | zip !ZIP_FILE_NAME! -@; STATUS=$?; if [ $TEMP_GIT -eq 1 ]; then rm -rf !SELECTED_DIR!/.git; fi; exit $STATUS"
)

if %ERRORLEVEL% NEQ 0 (echo. & echo Failed to create zip archive on the server. & goto end)
echo.
echo New zip archive created successfully.

:skip_zip

echo. & echo ---------------------------------------- & echo.

set "LOCAL_SAVE_NAME=!ZIP_FILE_NAME!"
if exist "!ZIP_FILE_NAME!" (
    :local_overwrite_prompt
    echo LOCAL WARNING: The file "!ZIP_FILE_NAME!" already exists in this folder.
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
        if /i not "!NEW_LOCAL_NAME:~-4!"==".zip" set "NEW_LOCAL_NAME=!NEW_LOCAL_NAME!.zip"
        set "LOCAL_SAVE_NAME=!NEW_LOCAL_NAME!"
    )
    if "%VALID_LOCAL_INPUT%"=="0" ( echo Invalid input. Please enter Y, N, or R. & echo. & goto :local_overwrite_prompt )
)

echo.
echo Starting download of "!ZIP_FILE_NAME!" as "!LOCAL_SAVE_NAME!"...
REM Added Keep-Alive to SCP as well
scp -o "ServerAliveInterval=30" %SSH_USER%@%SERVER_IP%:/home/%SSH_USER%/htdocs/"!ZIP_FILE_NAME!" "!LOCAL_SAVE_NAME!"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Download successful!
) else (
    echo.
    echo Download failed!
)

:end
echo. & echo ----------------------------------------
pause
endlocal