@ECHO OFF
SETLOCAL ENABLEEXTENSIONS
SETLOCAL ENABLEDELAYEDEXPANSION
CD /d "%~dp0\Source"

NET SESSION >NUL
IF %ERRORLEVEL% NEQ 0 (
    PAUSE
) ELSE (
    FOR /F %%i IN ('POWERSHELL -Command "$ExecutionContext.SessionState.LanguageMode"') DO (SET LANGMODE=%%i)
    IF "!LANGMODE!" == "FullLanguage" (
        FOR /F %%i IN ('POWERSHELL -Command "('RemoteSigned', 'Unrestricted').Contains((Get-ExecutionPolicy).ToString())"') DO (SET IS_UNRESTRICTED=%%i)
        POWERSHELL -Command "Unblock-File 'main.ps1'"
        POWERSHELL -Command "Unblock-File 'functions.psm1'"
        IF "!IS_UNRESTRICTED!" == "False" (
            FOR /F %%i IN ('POWERSHELL -Command """$(Get-ExecutionPolicy -Scope Machine)$(Get-ExecutionPolicy -Scope User)"""') DO (SET POLICY=%%i)
            IF "!POLICY!" NEQ "UndefinedUndefined" (
                POWERSHELL -Command "Write-Host 'POWERSHELL file script execution is managed by the system group policy. Change it before proceed' -ForegroundColor Red"
                ECHO Press "[ENTER]" to exit
                PAUSE >NUL
            ) ELSE (
                POWERSHELL -Command "Write-Host 'POWERSHELL file script execution policy is restricted!' -ForegroundColor Yellow"
                ECHO An POWERSHELL window will open with the following command:
                POWERSHELL -Command "Write-Host 'Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process;.\main.ps1' -ForegroundColor Cyan"
                ECHO Press "[ENTER]" to open POWERSHELL
                PAUSE >NUL
                POWERSHELL -NoExit -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process;.\main.ps1"
            )
        ) ELSE (
            POWERSHELL -file main.ps1
        )
    ) ELSE (
        ECHO POWERSHELL is not in "FullLanguage" mode. Change it before proceed
        PAUSE >NUL
    )
)
REM PAUSE
