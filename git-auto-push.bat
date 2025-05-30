@echo off
setlocal enabledelayedexpansion

:: Git Auto Push Batch Script
:: Windows version of the automated git workflow

:: Configuration
set MAX_RETRIES=5
set RETRY_DELAY=2

:: Colors (if supported)
set RED=[91m
set GREEN=[92m
set YELLOW=[93m
set BLUE=[94m
set NC=[0m

:: Get commit message or use default
if "%~1"=="" (
    for /f "tokens=1-4 delims=/ " %%a in ('date /t') do set mydate=%%c-%%a-%%b
    for /f "tokens=1-2 delims=: " %%a in ('time /t') do set mytime=%%a:%%b
    set COMMIT_MSG=Auto-commit: !mydate! !mytime!
) else (
    set COMMIT_MSG=%~1
)

echo %BLUE%[INFO]%NC% Starting automated git workflow...
echo %BLUE%[INFO]%NC% Commit message: !COMMIT_MSG!

:: Check if we're in a git repository
git rev-parse --git-dir >nul 2>&1
if errorlevel 1 (
    echo %RED%[ERROR]%NC% Not in a git repository!
    exit /b 1
)

:: Check for uncommitted changes
git diff-index --quiet HEAD --
if errorlevel 1 (
    echo %BLUE%[INFO]%NC% Changes detected, proceeding...
) else (
    echo %YELLOW%[WARNING]%NC% No changes to commit
    exit /b 0
)

:: Fetch remote changes
echo %BLUE%[INFO]%NC% Fetching remote changes...
git fetch origin
if errorlevel 1 (
    echo %YELLOW%[WARNING]%NC% Failed to fetch, continuing anyway...
)

:: Check for remote changes and pull if needed
for /f %%i in ('git rev-parse HEAD') do set LOCAL_COMMIT=%%i
for /f %%i in ('git rev-parse @{u} 2^>nul ^|^| echo ""') do set REMOTE_COMMIT=%%i

if not "!REMOTE_COMMIT!"=="" if not "!LOCAL_COMMIT!"=="!REMOTE_COMMIT!" (
    echo %BLUE%[INFO]%NC% Remote changes detected, pulling...
    for /f %%i in ('git branch --show-current') do set CURRENT_BRANCH=%%i
    git pull --rebase origin !CURRENT_BRANCH!
    if errorlevel 1 (
        echo %RED%[ERROR]%NC% Failed to pull remote changes
        exit /b 1
    )
)

:: Stage all changes
echo %BLUE%[INFO]%NC% Staging changes...
git add .
if errorlevel 1 (
    echo %RED%[ERROR]%NC% Failed to stage changes
    exit /b 1
)

:: Commit changes
echo %BLUE%[INFO]%NC% Committing changes...
git commit -m "!COMMIT_MSG!"
if errorlevel 1 (
    echo %RED%[ERROR]%NC% Failed to commit changes
    exit /b 1
)

:: Push changes with retry logic
set ATTEMPT=1
:push_loop
if !ATTEMPT! gtr %MAX_RETRIES% (
    echo %RED%[ERROR]%NC% Failed to push after %MAX_RETRIES% attempts
    exit /b 1
)

echo %BLUE%[INFO]%NC% Attempt !ATTEMPT!/%MAX_RETRIES%: Pushing changes...
for /f %%i in ('git branch --show-current') do set CURRENT_BRANCH=%%i
git push origin !CURRENT_BRANCH!

if errorlevel 1 (
    echo %YELLOW%[WARNING]%NC% Push failed, retrying in %RETRY_DELAY% seconds...
    timeout /t %RETRY_DELAY% /nobreak >nul
    set /a ATTEMPT+=1
    goto push_loop
)

echo %GREEN%[SUCCESS]%NC% All operations completed successfully!
echo %BLUE%[INFO]%NC% Changes pushed to origin/!CURRENT_BRANCH!

endlocal 