@ECHO OFF
@SETLOCAL ENABLEEXTENSIONS
@CD /d "%~dp0\Source"

NET SESSION >NUL
IF %ERRORLEVEL% NEQ 0 (
    PAUSE
) ELSE (
    CALL POWERSHELL -file main.ps1
    CD ..
)
REM PAUSE