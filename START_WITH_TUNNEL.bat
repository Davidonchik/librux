@echo off
echo ====================================
echo  Starting Librux with Cloudflare Tunnel
echo ====================================
echo.

echo [1] Building frontend...
call npm run build

echo.
echo [2] Stopping old servers and tunnels...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :3000') do (
    tasklist /FI "PID eq %%a" /FO CSV | findstr /I /C:"node.exe" >nul
    if not errorlevel 1 taskkill /F /PID %%a >nul 2>&1
)
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :3001') do (
    tasklist /FI "PID eq %%a" /FO CSV | findstr /I /C:"node.exe" >nul
    if not errorlevel 1 taskkill /F /PID %%a >nul 2>&1
)
REM Stop all cloudflared processes
taskkill /F /IM cloudflared.exe >nul 2>&1

timeout /t 2 /nobreak >nul

echo.
echo [3] Starting API server on port 3001...
start "Librux API" cmd /k "node server-api.js"

timeout /t 3 /nobreak >nul

echo.
echo [4] Starting frontend server on port 3000...
start "Librux Frontend" cmd /k "node server.js"

echo Waiting for server to be ready...
set /a attempts=0
:wait_server
timeout /t 2 /nobreak >nul
powershell -Command "try { $response = Invoke-WebRequest -Uri 'http://localhost:3000' -Method GET -TimeoutSec 2 -UseBasicParsing; exit 0 } catch { exit 1 }" >nul 2>&1
if %errorlevel% equ 0 goto server_ready
set /a attempts+=1
if %attempts% lss 10 goto wait_server

:server_ready
echo Server is ready!
timeout /t 2 /nobreak >nul

echo.
echo [5] Starting Cloudflare Tunnel...
echo    This will create a public URL for your site
echo.
echo ====================================
echo  Access your site:
echo  - Local:   http://localhost:3000
echo  - Tunnel:  (will be shown below)
echo ====================================
echo.

REM Start Cloudflare Tunnel in background and capture output
cd /d "%~dp0"
start /b cloudflared.exe tunnel --url http://localhost:3000 > tunnel-temp.txt 2>&1

echo Waiting for tunnel URL (max 30 seconds)...
timeout /t 15 /nobreak >nul

REM Use PowerShell script to extract URL, create redirect, and push to GitHub
powershell -ExecutionPolicy Bypass -File "create-redirect.ps1"

echo.
echo ====================================
echo  Tunnel is running in background
echo  Check tunnel-temp.txt for full output
echo ====================================
echo.
echo If git is set up, redirect.html was automatically pushed to GitHub!
echo.
echo Press any key to exit...
pause >nul
