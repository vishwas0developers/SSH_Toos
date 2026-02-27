@echo off
setlocal EnableDelayedExpansion

:: Clear the screen for a clean start
cls

:: —————————————————————————————
:: 📌 Step 1: Server IP Selection Menu
:: —————————————————————————————
:server_menu
echo Select your server:
echo [1] 88.222.244.186
echo [2] 168.231.102.163
echo [3] Enter manually
echo.

set "SERVER_CHOICE="
set /p SERVER_CHOICE="Enter your choice (1/2/3): "

if "%SERVER_CHOICE%"=="1" (
    set "SERVER_IP=88.222.244.186"
) else if "%SERVER_CHOICE%"=="2" (
    set "SERVER_IP=168.231.102.163"
) else if "%SERVER_CHOICE%"=="3" (
    echo.
    set /p SERVER_IP="Enter custom server IP or domain (e.g. cp.yourdomain.com): "
    if not defined SERVER_IP (
        echo.
        echo ❌ Invalid input. Please enter an IP or domain.
        echo.
        goto server_menu
    )
) else (
    echo.
    echo ❌ Invalid choice. Please enter 1, 2, or 3.
    echo.
    goto server_menu
)

echo.
echo ----------------------------------------
echo.

:: —————————————————————————————
:: 👤 Step 2: SSH Username Prompt
:: —————————————————————————————
:username_prompt
set "SSH_USER="
set /p SSH_USER="Enter SSH username (e.g. online2study-front): "

if not defined SSH_USER (
    echo.
    echo ❌ Username cannot be empty.
    echo.
    goto username_prompt
)

echo.
echo ----------------------------------------
echo.

:: —————————————————————————————
:: 📁 Step 3: File Selection Menu
:: —————————————————————————————
:file_menu
echo Files in current folder:
set "FILE_COUNT=0"

:: Loop through all files in the current directory
for %%F in (*) do (
    set /a FILE_COUNT+=1
    set "FILE[!FILE_COUNT!]=%%F"
    echo [!FILE_COUNT!] %%F
)

echo.
set "FILE_CHOICE="
set /p FILE_CHOICE="Enter file number to upload: "

:: Validate user input
if not defined FILE_CHOICE (
    echo.
    echo ❌ No selection made. Please try again.
    echo.
    goto file_menu
)

:: Check if the choice is a valid number within the range
if %FILE_CHOICE% GTR 0 if %FILE_CHOICE% LEQ %FILE_COUNT% (
    set "SELECTED_FILE=!FILE[%FILE_CHOICE%]!"
) else (
    echo.
    echo ❌ Invalid number. Please select a number from the list.
    echo.
    goto file_menu
)

echo.
echo ----------------------------------------
echo.
echo Preparing to upload "!SELECTED_FILE!" to %SSH_USER%@%SERVER_IP%...
echo.

:: —————————————————————————————
:: 📤 Step 4 & 5: Execute SCP Upload
:: —————————————————————————————
:: The password prompt is automatically handled by the scp command.
:: The target path is constructed using the SSH_USER variable.
scp "!SELECTED_FILE!" %SSH_USER%@%SERVER_IP%:/home/%SSH_USER%/htdocs/

:: —————————————————————————————
:: ✅ Step 6: Confirmation or Error
:: —————————————————————————————
:: Check the exit code of the last command (scp).
:: An ERRORLEVEL of 0 means success, anything else is a failure.
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ Upload successful!
) else (
    echo.
    echo ❌ Upload failed!
)

echo.
echo ----------------------------------------
pause
endlocal