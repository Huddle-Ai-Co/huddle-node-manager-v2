@echo off
REM Windows Compatibility Test for HNM Installation
REM Tests the dynamic installation script on Windows systems

echo ========================================
echo HNM Windows Compatibility Test
echo ========================================
echo.

REM Check if WSL is available
echo Checking WSL availability...
wsl --version >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ WSL is available
    echo.
    echo Testing WSL compatibility...
    
    REM Test in WSL Ubuntu
    wsl -d Ubuntu-22.04 -e bash -c "
        echo 'Testing HNM installation in WSL...'
        cd /mnt/c/Users/%USERNAME%/Downloads/huddle-node-manager 2>/dev/null || cd ~
        
        if [ -f 'test_installation_paths_dynamic.sh' ]; then
            chmod +x test_installation_paths_dynamic.sh
            ./test_installation_paths_dynamic.sh
        else
            echo 'Test files not found in WSL'
            echo 'Please copy test files to WSL environment'
        fi
    "
) else (
    echo ❌ WSL not available
    echo.
    echo Testing native Windows compatibility...
    
    REM Test native Windows paths
    echo Checking Windows paths...
    
    REM Set Windows-specific paths
    set HNM_LIB_DIR=%APPDATA%\huddle-node-manager\lib
    set HNM_CONFIG_DIR=%APPDATA%\huddle-node-manager\config
    set HNM_BIN_DIR=%APPDATA%\huddle-node-manager\bin
    
    echo Windows Library Directory: %HNM_LIB_DIR%
    echo Windows Config Directory: %HNM_CONFIG_DIR%
    echo Windows Binary Directory: %HNM_BIN_DIR%
    
    REM Check if directories exist
    if exist "%HNM_LIB_DIR%" (
        echo ✅ Windows library directory exists
    ) else (
        echo ❌ Windows library directory missing
    )
    
    if exist "%HNM_CONFIG_DIR%" (
        echo ✅ Windows config directory exists
    ) else (
        echo ❌ Windows config directory missing
    )
    
    if exist "%HNM_BIN_DIR%" (
        echo ✅ Windows binary directory exists
    ) else (
        echo ❌ Windows binary directory missing
    )
)

echo.
echo ========================================
echo Windows Compatibility Test Summary
echo ========================================
echo.

if %errorlevel% equ 0 (
    echo ✅ Windows compatibility test completed
    echo.
    echo Recommendations:
    echo 1. Install WSL2 for best compatibility
    echo 2. Use WSL Ubuntu for Linux-like environment
    echo 3. Run HNM installation in WSL environment
) else (
    echo ❌ Windows compatibility test failed
    echo.
    echo Recommendations:
    echo 1. Install WSL2: wsl --install
    echo 2. Install Ubuntu in WSL: wsl --install -d Ubuntu-22.04
    echo 3. Run HNM installation in WSL environment
)

echo.
echo For more information, see: cross_platform_testing.md
pause 