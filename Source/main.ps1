#$global:DebugPreference = 'Continue'
#Requires -RunAsAdministrator

Import-Module .\functions.psm1

<# ================================ MAIN SCRIPT ================================ #>
if (-Not (Get-IsWindows11)) {
    Write-Warning 'Asus Setup Tool may not be compatible with Windows 11'
    if ((Read-HostColor 'Still proceed? [Y] Yes [N] No' Yellow) -eq 'N') {
        Exit
    }
}
Import-Config
Write-HeaderTitle


$HasAiSuite = Test-Path "${Env:ProgramFiles(x86)}\Asus\AI Suite III\AISuite3.exe"
try {
    New-Item '..\Apps' -ItemType Directory -Force | Out-Null
} catch {
    Resolve-Error $_.Exception 'Failed to create folder "Apps"'
}



Write-Host "GET ASUS SETUP" -ForegroundColor Green
$HasLiveDash = Read-Host 'Do you want LiveDash (controls OLED screen)? [Y] Yes [N] No'
if ($HasLiveDash -eq 'Y') {
    Write-Warning 'LiveDash requirements may not be compatible with products **AFTER 2020**'
    $AuraPatch = '..\Patches\AuraSyncOld\*'
    $LiveDashUrl = $SetupSettings.LiveDashUrl
} else {
    $AuraPatch = '..\Patches\AuraSyncNew\*'
    $LiveDashUrl = ''
}

try {
    Get-ASUSSetup -LiveDashUrl $LiveDashUrl -ErrorAction Stop
} catch {
    try {
        #If failed download is not trustable
        Remove-Item '..\Apps' -Force -Recurse -ErrorAction Stop
    } catch {
        Resolve-Error $_.Exception 'Failed to remove "Apps"'
    }
    Resolve-Error $_.Exception 'Failed to get AsusSetup. Try again'
}

Write-Host 'Patching AiSuite3...'
try {
    Copy-Item '..\Patches\AiSuite3\DrvResource\*' (Resolve-Path '..\Apps\AiSuite3\DrvResource').Path -Recurse -Force -ErrorAction Stop
} catch {
    Resolve-Error $_.Exception
}

Write-Host 'Patching AuraSync...'
try {
    $AuraPath = (Resolve-Path '..\Apps\AuraSync\*').Path

    #First copy newer MB & Display Hal Setups
    if ($SetupSettings.HasLiveDash) {
        $AuraModulesPath = "$AuraPath\LightingService"
        Copy-Item "$AuraModulesPath\aac\AacMBSetup.exe" "$Env:TEMP\AacMBSetup.exe" -Force -ErrorAction Stop
    } else {
        $AuraModulesPath = "$AuraPath\LightingService\LSInstall"
        Copy-Item "$AuraModulesPath\aac\Hal\AacMBSetup.exe" "$Env:TEMP\AacMBSetup.exe" -Force -ErrorAction Stop
    }
    Copy-Item "$AuraModulesPath\aac\AacDisplaySetup.exe" "$Env:TEMP\AacDisplaySetup.exe" -Force -ErrorAction Stop
    Copy-Item $AuraPatch $AuraPath -Recurse -Force -ErrorAction Stop
    $FullInstall = Read-Host 'Add all AuraSync modules? [Y] Yes [N] No'
    if ($FullInstall -eq 'N') {
        Write-Host 'Updating AuraSync modules...'
        Update-AuraModules $AuraModulesPath -ErrorAction Stop
    }
} catch {
    Resolve-Error $_.Exception
}

if ($SetupSettings.HasLiveDash) {
    Write-Host 'Patching LiveDash...'
    try {
        $LiveDashPath = (Resolve-Path '..\Apps\LiveDash\*').Path
        Remove-Item "$LiveDashPath\LightingService" -Recurse -Force -ErrorAction Stop
        Copy-Item "$AuraPath\LightingService" $LiveDashPath -Recurse -Force -ErrorAction Stop
        Copy-Item '..\Patches\LiveDash\*' $LiveDashPath -Recurse -Force -ErrorAction Stop
    } catch {
        Resolve-Error $_.Exception
    }
}



Write-Host "`nCLEAR ASUS BLOATWARE" -ForegroundColor Green
Clear-AsusBloat



if ((Read-Host 'Want to install apps now? [Y] Yes [N] No') -eq 'Y') {
    Write-Host "`nSET ASUS SERVICE" -ForegroundColor Green
    try {
        Set-AsusService (Resolve-Path '..\Apps\AiSuite3\Setup.exe').Path
    } catch {
        Resolve-Error $_.Exception
    }
    Start-Sleep 2



    Write-Host "`nINSTALL ASUS SETUP" -ForegroundColor Green
    Write-Host 'Installing Aura Sync...'
    try {
        Start-Process "$AuraPath\Setup.exe" -ArgumentList '/s /norestart' -Wait
        Start-Sleep 2
        if (-not (Test-Path "${Env:ProgramFiles(x86)}\LightingService")) {
            throw 'Failed to install aura sync. Try again'
        }
    } catch {
        Resolve-Error $_.Exception
    }
    if ($SetupSettings.HasLiveDash) {
        Write-Host 'Installing LiveDash...'
        try {
            Start-Process "$LiveDashPath\Setup.exe" -ArgumentList '/s /norestart' -Wait -ErrorAction Stop
            Start-Sleep 2
        } catch {
            Resolve-Error $_.Exception
        }

        Write-Host 'Stopping LightingService...'
        try {
            Stop-Service -Name 'LightingService' -ErrorAction Stop
            Remove-Item "${Env:ProgramFiles(x86)}\LightingService\LastProfile.xml" -Force -ErrorAction SilentlyContinue
        } catch {
            Resolve-Error $_.Exception
        }

        if (Get-ChildItem "$AuraPath\LightingService\*AacMBSetup.exe" -Recurse) {
            Write-Host 'Updating MB Hal...'
            try {
                Start-Process "$Env:TEMP\AacMBSetup.exe" -ArgumentList '/s /norestart' -Wait -ErrorAction Stop
            } catch {
                Resolve-Error $_.Exception
            }
        }

        if (Get-ChildItem "$AuraPath\LightingService\*AacDisplaySetup.exe" -Recurse) {
            Write-Host 'Updating Display Hal...'
            try {
                Start-Process "$Env:TEMP\AacDisplaySetup.exe" -ArgumentList '/s /norestart' -Wait -ErrorAction Stop
            } catch {
                Resolve-Error $_.Exception
            }
        }
    }

    #Set local profiles if exist
    if (Test-Path '..\Patches\Profiles\LastProfile.xml') {
        Update-AsusService
    }

    if ((Read-Host 'Want to install AiSuite 3? [Y] Yes [N] No') -eq 'Y') {
        if ($HasAiSuite) {
            Write-Warning 'Reboot is required after AiSuite3 uninstallation. Install manually later on folder "Apps\AiSuite3"'
        } else {
            Write-Host 'Installing AiSuite 3...'
            try {
                Start-Process '..\Apps\AiSuite3\AsusSetup.exe' -ArgumentList '/s /norestart' -Wait
                Start-Sleep 2
            } catch {
                Resolve-Error $_.Exception
            }
        }
    }

    Write-Output 'Removing temp files...'
    Remove-FileFolder $Env:TEMP -ErrorAction SilentlyContinue
}



$Emoji = Convert-UnicodeToEmoji '1F389'
Write-Host "`n$Emoji ASUS SETUP TOOL FINISHED WITH SUCCESS! $Emoji" -ForegroundColor Green
if ((Read-Host 'Reboot system now (recommended)? [Y] Yes [N] No') -eq 'Y') {
    shutdown /r /t 5 /c "System will restart"
}
