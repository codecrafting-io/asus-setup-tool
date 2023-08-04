#$global:DebugPreference = 'Continue'
#Requires -RunAsAdministrator

Import-Module .\functions.psm1

<# ================================ MAIN SCRIPT ================================ #>
if (-Not (Get-IsWindows11)) {
    Write-Warning 'Asus Setup Tool may not be compatible with Windows 11'
    if ((Read-HostColor 'Do you still wish to proceed [Y] Yes [N] No' Yellow) -eq 'N') {
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
$IsLiveDash = Read-Host 'Do you want LiveDash (controls OLED screen)? [Y] Yes [N] No'
if ($IsLiveDash -eq 'Y') {
    Write-Warning 'LiveDash requirements may not be compatible with products **AFTER 2021**'
    $AuraPatch = '..\Patches\AuraSyncOld\*'
    $LiveDashUrl = $SetupSettings.LiveDashUrl
} else {
    $AuraPatch = '..\Patches\AuraSyncNew\*'
    $LiveDashUrl = ''
}

try {
    Get-ASUSSetup $LiveDashUrl -ErrorAction Stop
} catch {
    try {
        #If failed download is not trustable
        Remove-Item '..\Apps' -Force -Recurse -ErrorAction Stop
    } catch {
        Resolve-Error $_.Exception 'Failed to remove "Apps"'
    }
    Resolve-Error $_.Exception 'Failed to get AsusSetup'
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
    Copy-Item "$AuraPath\LightingService\aac\AacMBSetup.exe" "$Env:TEMP\AacMBSetup.exe" -Force -ErrorAction Stop
    Copy-Item "$AuraPath\LightingService\aac\AacDisplaySetup.exe" "$Env:TEMP\AacDisplaySetup.exe" -Force -ErrorAction Stop
    Copy-Item $AuraPatch $AuraPath -Recurse -Force -ErrorAction Stop
    $FullInstall = Read-Host 'Add all AuraSync modules? [Y] Yes [N] No'
    if ($FullInstall -eq 'N') {
        Write-Host 'Updating AuraSync modules...'
        Update-AuraModules "$AuraPath\LightingService" ([boolean] $LiveDashUrl) -ErrorAction Stop
    }
} catch {
    Resolve-Error $_.Exception
}

if ($LiveDashUrl) {
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



if ((Read-Host 'Do you want install apps now? [Y] Yes [N] No') -eq 'Y') {
    Write-Host "`nSET ASUS SERVICE" -ForegroundColor Green
    try {
        Set-AsusService (Resolve-Path '..\Apps\AiSuite3\Setup.exe').Path
    } catch {
        Resolve-Error $_.Exception
    }



    Write-Host "`nINSTALL ASUS SETUP" -ForegroundColor Green
    Write-Host 'Installing Aura Sync...'
    try {
        Start-Process "$AuraPath\Setup.exe" -ArgumentList '/s' -Wait
        Start-Sleep 2
        if (-not (Test-Path "${Env:ProgramFiles(x86)}\LightingService")) {
            throw 'Failed to install aura sync. Try again'
        }
    } catch {
        Resolve-Error $_.Exception
    }
    if ($LiveDashUrl) {
        Write-Host 'Installing LiveDash...'
        try {
            Start-Process "$LiveDashPath\AsusSetup.exe" -ArgumentList '/s' -Wait -ErrorAction Stop
        } catch {
            Resolve-Error $_.Exception
        }

        Write-Host 'Stopping LightingService...'
        try {
            Stop-Service -Name 'LightingService'
            Remove-Item "${Env:ProgramFiles(x86)}\LightingService\LastProfile.xml" -Force -ErrorAction SilentlyContinue
        } catch {
            Resolve-Error $_.Exception
        }

        if (Get-ChildItem "$AuraPath\LightingService\aac\*AacMBSetup.exe") {
            Write-Host 'Updating MB Hal...'
            try {
                Start-Process "$Env:TEMP\AacMBSetup.exe" -ArgumentList '/s' -Wait -ErrorAction Stop
            } catch {
                Resolve-Error $_.Exception
            }
        }

        if (Get-ChildItem "$AuraPath\LightingService\aac\*AacDisplaySetup.exe") {
            Write-Host 'Updating Display Hal...'
            try {
                Start-Process "$Env:TEMP\AacDisplaySetup.exe" -ArgumentList '/s' -Wait -ErrorAction Stop
            } catch {
                Resolve-Error $_.Exception
            }
        }
    }

    if ((Read-Host 'Do you want to install AiSuite 3? [Y] Yes [N] No') -eq 'Y') {
        if ($HasAiSuite) {
            Write-Warning 'Reboot is required after AiSuite3 uninstallation. Install manually on folder "Apps\AiSuite3"'
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
