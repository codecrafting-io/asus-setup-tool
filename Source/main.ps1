#$global:DebugPreference = 'SilentlyContinue'
#Requires -RunAsAdministrator

Import-Module .\functions.psm1

<# ================================ MAIN SCRIPT ================================ #>
if (-Not (Get-IsWindows11)) {
    Write-Warning 'Asus Setup Tool may not be compatible with Windows 11'
    if ((Read-HostColor 'Do you still wish to proceed [Y] Yes [N] No' yellow) -eq 'N') {
        Exit
    }
}
Import-Config
Write-HeaderTitle


$hasAiSuite = Test-Path "${Env:ProgramFiles(x86)}\Asus\AI Suite III\AISuite3.exe"
try {
    New-Item '..\Apps' -ItemType Directory -Force | Out-Null
} catch {
    Resolve-Error $_.Exception 'Failed to create folder "Apps"'
}



Write-Host "GET ASUS SETUP" -ForegroundColor green
$isLiveDash = Read-Host 'do you want LiveDash (controls OLED screen)? [Y] Yes [N] No'
if ($isLiveDash -eq 'Y') {
    Write-Warning 'LiveDash requirements may not be compatible with products **AFTER 2021**'
    $auraPatch = '..\Patches\AuraSyncOld\*'
} else {
    $auraPatch = '..\Patches\AuraSyncNew\*'
    $LiveDashUrl = ''
}

try {
    Get-AsusSetup $LiveDashUrl -ErrorAction Stop
} catch {
    try {
        Remove-Item '..\Apps' -Force -Recurse -ErrorAction Stop
    } catch {
        Resolve-Exception $_.Exception 'Failed to remove "Apps"'
    }
    Resolve-Error $_.Exception 'Failed to get AsusSetup'
}

Write-Host 'patching AiSuite3...'
try {
    Copy-Item '..\Patches\AiSuite3\DrvResource\*' (Resolve-Path '..\Apps\AiSuite3\DrvResource').Path -Recurse -Force -ErrorAction Stop
} catch {
    Resolve-Error $_.Exception
}

Write-Host 'patching AuraSync...'
try {
    $auraPath = (Resolve-Path '..\Apps\AuraSync\*').Path

    #First copy newer MB & Display Hal Setups
    Copy-Item "$auraPath\LightingService\aac\AacMBSetup.exe" "$env:TEMP\AacMBSetup.exe" -Force -ErrorAction Stop
    Copy-Item "$auraPath\LightingService\aac\AacDisplaySetup.exe" "$env:TEMP\AacDisplaySetup.exe" -Force -ErrorAction Stop
    Copy-Item $auraPatch $auraPath -Recurse -Force -ErrorAction Stop
    $fullInstall = Read-Host 'add all AuraSync modules? [Y] Yes [N] No'
    if ($fullInstall -eq 'N') {
        Write-Host 'updating AuraSync modules...'
        Update-AuraModules "$auraPath\LightingService" ([boolean] $LiveDashUrl) -ErrorAction Stop
    }
} catch {
    Resolve-Error $_.Exception
}

if ($LiveDashUrl) {
    Write-Host 'patching LiveDash...'
    try {
        $liveDashPath = (Resolve-Path '..\Apps\LiveDash\*').Path
        Remove-Item "$liveDashPath\LightingService" -Recurse -Force -ErrorAction Stop
        Copy-Item "$auraPath\LightingService" $liveDashPath -Recurse -Force -ErrorAction Stop
        Copy-Item '..\Patches\LiveDash\*' $liveDashPath -Recurse -Force -ErrorAction Stop
    } catch {
        Resolve-Error $_.Exception
    }
}



Write-Host "`nCLEAR ASUS BLOATWARE" -ForegroundColor green
Clear-AsusBloat



if ((Read-Host 'do you want install apps now? [Y] Yes [N] No') -eq 'Y') {
    Write-Host "`nSET ASUS SERVICE" -ForegroundColor green
    try {
        Set-AsusService (Resolve-Path '..\Apps\AiSuite3\Setup.exe').Path
    } catch {
        Resolve-Error $_.Exception
    }



    Write-Host "`nINSTALL ASUS SETUP" -ForegroundColor green
    Write-Host 'installing Aura Sync...'
    try {
        Start-Process "$auraPath\Setup.exe" -ArgumentList '/s' -Wait
        Start-Sleep 2
        if (-not (Test-Path "${Env:ProgramFiles(x86)}\LightingService")) {
            throw 'Failed to install aura sync. Try again'
        }
    } catch {
        Resolve-Error $_.Exception
    }
    if ($LiveDashUrl) {
        Write-Host 'installing LiveDash...'
        try {
            Start-Process "$liveDashPath\AsusSetup.exe" -ArgumentList '/s' -Wait -ErrorAction Stop
        } catch {
            Resolve-Error $_.Exception
        }

        Write-Host 'stopping LightingService...'
        try {
            Stop-Service -Name 'LightingService'
            Remove-Item "${Env:ProgramFiles(x86)}\LightingService\LastProfile.xml" -Force -ErrorAction SilentlyContinue
        } catch {
            Resolve-Error $_.Exception
        }

        if (Get-ChildItem "$auraPath\LightingService\aac\*AacMBSetup.exe") {
            Write-Host 'updating MB Hal...'
            try {
                Start-Process "$env:TEMP\AacMBSetup.exe" -ArgumentList '/s' -Wait -ErrorAction Stop
            } catch {
                Resolve-Error $_.Exception
            }
        }

        if (Get-ChildItem "$auraPath\LightingService\aac\*AacDisplaySetup.exe") {
            Write-Host 'updating Display Hal...'
            try {
                Start-Process "$env:TEMP\AacDisplaySetup.exe" -ArgumentList '/s' -Wait -ErrorAction Stop
            } catch {
                Resolve-Error $_.Exception
            }
        }
    }

    if ((Read-Host 'do you want to install AiSuite 3? [Y] Yes [N] No') -eq 'Y') {
        if ($hasAiSuite) {
            Write-Warning 'reboot is required after AiSuite3 uninstallation. Install manually on folder "Apps\AiSuite3"'
        } else {
            Write-Host 'installing AiSuite 3...'
            try {
                Start-Process '..\Apps\AiSuite3\AsusSetup.exe' -ArgumentList '/s /norestart' -Wait
                Start-Sleep 2
            } catch {
                Resolve-Error $_.Exception
            }
        }
    }

    Write-Output 'removing temp files...'
    Remove-FileFolder $env:TEMP -ErrorAction SilentlyContinue
}



$emoji = Convert-UnicodeToEmoji '1F389'
Write-Host "`n$emoji ASUS SETUP TOOL FINISHED WITH SUCCESS! $emoji" -ForegroundColor green
if ((Read-Host 'Reboot system now (recommended)? [Y] Yes [N] No') -eq 'Y') {
    shutdown /r /t 5 /c "System will restart"
}
