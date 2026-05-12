@echo off
setlocal EnableDelayedExpansion
cls

:server_menu
echo Select your server:
echo [1] 1. server
echo [2] 2. server
echo [3] Enter manually
echo.

set "SERVER_CHOICE="
set /p SERVER_CHOICE="Enter your choice (1/2/3): "

if "%SERVER_CHOICE%"=="1" (
    set "SERVER_IP="
    set /p SERVER_IP="Enter 1. server IP or domain: "
) else if "%SERVER_CHOICE%"=="2" (
    set "SERVER_IP="
    set /p SERVER_IP="Enter 2. server IP or domain: "
) else if "%SERVER_CHOICE%"=="3" (
    echo.
    set "SERVER_IP="
    set /p SERVER_IP="Enter custom server IP or domain: "
    if not defined SERVER_IP (
        echo.
        echo Invalid input. Please enter an IP or domain.
        echo.
        goto server_menu
    )
) else (
    echo.
    echo Invalid choice. Please enter 1, 2, or 3.
    echo.
    goto server_menu
)

echo.
echo ----------------------------------------
echo.

:username_prompt
set "SSH_USER="
set /p SSH_USER="Enter SSH username: "

if not defined SSH_USER (
    echo.
    echo Username cannot be empty.
    echo.
    goto username_prompt
)

set "REMOTE_BASE=/home/%SSH_USER%/htdocs"
set "PATH=%PATH%;C:\Program Files\PuTTY"
where plink.exe >nul 2>nul
if errorlevel 1 (
    echo.
    echo PuTTY tools not found.
    echo Please install PuTTY or add C:\Program Files\PuTTY to PATH.
    echo.
    pause
    exit /b 1
)

set "SSH_PASS="
echo.
:password_prompt
for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "$p=Read-Host 'Enter SSH password' -AsSecureString; $b=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($p); [Runtime.InteropServices.Marshal]::PtrToStringAuto($b)"`) do set "SSH_PASS=%%P"
if not defined SSH_PASS (
    echo.
    echo Password cannot be empty.
    echo.
    goto password_prompt
)

echo.
echo Establishing SSH connection...
echo.
echo y | plink.exe -ssh -l %SSH_USER% -pw "%SSH_PASS%" %SERVER_IP% "exit" >nul 2>nul
if errorlevel 1 (
    echo.
    echo Failed to establish SSH connection.
    echo.
    pause
    exit /b 1
)

echo.
echo ----------------------------------------
echo.

:local_file_menu
echo Select a local file to upload:
echo [0] Enter full file path
set "FILE_COUNT=0"

for %%F in (*) do (
    if not exist "%%~fF\NUL" (
        set /a FILE_COUNT+=1
        set "FILE[!FILE_COUNT!]=%%~fF"
        echo [!FILE_COUNT!] %%~nxF
    )
)

if !FILE_COUNT! EQU 0 (
    echo No files found in the current folder.
)

echo.
set "FILE_CHOICE="
set /p FILE_CHOICE="Enter file number or 0: "

if not defined FILE_CHOICE (
    echo.
    echo No selection made. Please try again.
    echo.
    goto local_file_menu
)

set "FILE_CHOICE_NUM="
set /a FILE_CHOICE_NUM=FILE_CHOICE >nul 2>nul

if errorlevel 1 (
    echo.
    echo Invalid choice. Please enter 0 or a listed number.
    echo.
    goto local_file_menu
)

if "%FILE_CHOICE_NUM%"=="0" goto direct_file_path

if !FILE_CHOICE_NUM! GTR 0 if !FILE_CHOICE_NUM! LEQ !FILE_COUNT! (
    call set "SELECTED_FILE=%%FILE[!FILE_CHOICE_NUM!]%%"
) else (
    echo.
    echo Invalid number. Please select a number from the list.
    echo.
    goto local_file_menu
)

goto remote_folder_menu

:direct_file_path
echo.
:direct_file_path_prompt
set "DIRECT_FILE="
set /p DIRECT_FILE="Paste full file path: "

if not defined DIRECT_FILE (
    echo.
    echo File path cannot be empty.
    echo.
    goto direct_file_path_prompt
)

set "DIRECT_FILE=!DIRECT_FILE:"=!"

if not exist "!DIRECT_FILE!" (
    echo.
    echo File not found. Please try again.
    echo.
    goto direct_file_path_prompt
)

if exist "!DIRECT_FILE!\NUL" (
    echo.
    echo The selected path is a folder, not a file.
    echo.
    goto direct_file_path_prompt
)

for %%I in ("!DIRECT_FILE!") do set "SELECTED_FILE=%%~fI"

goto remote_folder_menu

:build_remote_rel
set "REMOTE_REL="
if !REMOTE_DEPTH! GTR 0 (
    for /l %%I in (1,1,!REMOTE_DEPTH!) do (
        call set "REMOTE_SEG_CURRENT=%%REMOTE_SEG[%%I]%%"
        if defined REMOTE_REL (
            set "REMOTE_REL=!REMOTE_REL!/!REMOTE_SEG_CURRENT!"
        ) else (
            set "REMOTE_REL=!REMOTE_SEG_CURRENT!"
        )
    )
)
goto :eof

:remote_folder_menu
if not defined REMOTE_DEPTH set "REMOTE_DEPTH=0"
call :build_remote_rel

set "REMOTE_CURRENT=%REMOTE_BASE%"
if defined REMOTE_REL set "REMOTE_CURRENT=%REMOTE_BASE%/!REMOTE_REL!"

echo.
echo Remote destination browser
echo Current folder: !REMOTE_CURRENT!
echo [0] Back

set "REMOTE_COUNT=0"
for /f "delims=" %%D in ('plink.exe -batch -ssh -l %SSH_USER% -pw "%SSH_PASS%" %SERVER_IP% "cd ""!REMOTE_CURRENT!"" && find . -mindepth 1 -maxdepth 1 -type d -printf ""%%f\n"" 2>/dev/null | sort" 2^>nul') do (
    set /a REMOTE_COUNT+=1
    set "REMOTE_DIR[!REMOTE_COUNT!]=%%D"
    echo [!REMOTE_COUNT!] %%D
)

if !REMOTE_COUNT! EQU 0 (
    echo No subfolders found in this folder.
)

echo.
echo Press Enter to upload to this folder
echo.
set "REMOTE_CHOICE="
set /p REMOTE_CHOICE="Choose folder number, 0 to go back, or Enter to confirm: "

if not defined REMOTE_CHOICE goto remote_confirm

set "REMOTE_CHOICE_NUM="
set /a REMOTE_CHOICE_NUM=REMOTE_CHOICE >nul 2>nul

if errorlevel 1 (
    echo.
    echo Invalid choice. Please enter 0, a folder number, or press Enter.
    echo.
    goto remote_folder_menu
)

if "%REMOTE_CHOICE_NUM%"=="0" goto remote_back

if !REMOTE_CHOICE_NUM! GTR 0 if !REMOTE_CHOICE_NUM! LEQ !REMOTE_COUNT! (
    set /a REMOTE_DEPTH+=1
    call set "REMOTE_SEG[!REMOTE_DEPTH!]=%%REMOTE_DIR[!REMOTE_CHOICE_NUM!]%%"
    goto remote_folder_menu
) else (
    echo.
    echo Invalid folder number.
    echo.
    goto remote_folder_menu
)

:remote_back
if !REMOTE_DEPTH! LEQ 0 (
    echo.
    echo You are already at the root htdocs folder.
    echo.
    goto remote_folder_menu
)

set "REMOTE_SEG[!REMOTE_DEPTH!]="
set /a REMOTE_DEPTH-=1
goto remote_folder_menu

:remote_confirm
call :build_remote_rel
set "REMOTE_TARGET=%REMOTE_BASE%"
if defined REMOTE_REL set "REMOTE_TARGET=%REMOTE_BASE%/!REMOTE_REL!"

echo.
echo Preparing to upload "!SELECTED_FILE!" to %SSH_USER%@%SERVER_IP%:"!REMOTE_TARGET!/"
echo.

pscp.exe -batch -l %SSH_USER% -pw "%SSH_PASS%" "!SELECTED_FILE!" %SSH_USER%@%SERVER_IP%:"!REMOTE_TARGET!/"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Upload successful!
) else (
    echo.
    echo Upload failed!
)

:upload_end
echo.
echo ----------------------------------------
pause
endlocal
