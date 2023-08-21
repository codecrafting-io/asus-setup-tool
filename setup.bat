@ECHO OFF
@SETLOCAL ENABLEEXTENSIONS
CD /d "%~dp0\Source"

FOR /F %%i IN ('POWERSHELL -Command "Get-ExecutionPolicy"') DO (SET POLICY=%%i)

NET SESSION >NUL
IF %ERRORLEVEL% NEQ 0 (
    PAUSE
) ELSE (
    IF "%POLICY%" == "Restricted" (
        REM Bypass solution
        POWERSHELL -Command "Write-Host 'POWERSHELL file script execution policy is disabled!' -ForegroundColor Yellow"
        ECHO An POWERSHELL window will open with the following command:
        POWERSHELL -Command "Write-Host 'Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process;.\main.ps1' -ForegroundColor Cyan"
        ECHO Press "[ENTER]" to open POWERSHELL
        PAUSE >NUL
        START POWERSHELL -NoExit -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process;.\main.ps1"
    ) else (
        CALL POWERSHELL -file main.ps1
        CD ..
    )
)
REM PAUSE
