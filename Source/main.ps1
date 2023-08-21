#$global:DebugPreference = 'Continue'
#Requires -RunAsAdministrator

Import-Module .\functions.psm1

<# ================================ MAIN SCRIPT ================================ #>

<#
if (-Not (Get-IsWindows11)) {
    Write-Warning 'Asus Setup Tool may not be compatible with Windows 11'
    if ((Read-HostColor 'Still proceed? [Y] Yes [N] No' Yellow) -eq 'N') {
        Exit
    }
}
#>
Import-Config
Write-HeaderTitle

$HasAiSuite = Test-Path "${Env:ProgramFiles(x86)}\Asus\AI Suite III\AISuite3.exe"
try {
    New-Item '..\Apps' -ItemType Directory -Force | Out-Null
} catch {
    Resolve-Error $_.Exception 'Failed to create folder "Apps"'
}




Write-Host 'GET ASUS SETUP' -ForegroundColor Green
if ((Read-Host 'Do you want LiveDash (controls OLED screen)? [Y] Yes [N] No') -eq 'Y') {
    Write-Warning 'LiveDash requires LightingService patching which may not be compatible with products after 2020'
    $LiveDashUrl = $SetupSettings.LiveDashUrl
} else {
    $LiveDashUrl = ''
}

try {
    Get-ASUSSetup -LiveDashUrl $LiveDashUrl -ErrorAction Stop
} catch {
    Resolve-Error $_.Exception 'Failed to get AsusSetup. Try again'
}

Write-Host 'Patching AiSuite3 setup...'
try {
    Copy-Item '..\Patches\AiSuite3\DrvResource\*' '..\Apps\AiSuite3\DrvResource' -Recurse -Force -ErrorAction Stop
} catch {
    Resolve-Error $_.Exception
}

Write-Host 'Patching AuraSync setup...'
try {
    $AuraPath = (Resolve-Path '..\Apps\AuraSync\*').Path
    if ($SetupSettings.IsOldAura) {
        $AuraModulesPath = "$AuraPath\LightingService"
    } else {
        $AuraModulesPath = "$AuraPath\LightingService\LSInstall"
    }

    #Replaces AXSP
    Copy-Item '..\Patches\AiSuite3\DrvResource\AXSP\*' (Get-ChildItem '..\Apps\AuraSync\*AXSP' -Recurse).FullName -Recurse -Force -ErrorAction Stop
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
        Copy-Item '..\Patches\AiSuite3\DrvResource\AXSP\*' "$LiveDashPath\AXSP" -Recurse -Force -ErrorAction Stop
        Copy-Item "$AuraPath\LightingService" $LiveDashPath -Recurse -Force -ErrorAction Stop
    } catch {
        Resolve-Error $_.Exception
    }
}




Write-Host "`nCLEAR ASUS BLOATWARE" -ForegroundColor Green
Clear-AsusBloat




if ((Read-Host 'Want to install apps now? [Y] Yes [N] No') -eq 'Y') {
    Write-Host "`nINSTALL ASUS SETUP" -ForegroundColor Green
    try {
        Set-AsusService (Resolve-Path '..\Apps\AiSuite3\Setup.exe').Path
    } catch {
        Resolve-Error $_.Exception
    }
    Start-Sleep 5
    Write-Host 'Installing Aura Sync...'
    try {
        Start-Process "$AuraPath\Setup.exe" -ArgumentList '/s /norestart' -Wait
        if (-not (Test-Path "${Env:ProgramFiles(x86)}\LightingService")) {
            throw 'Failed to install aura sync. Try again'
        }
        Start-Sleep 2
    } catch {
        Resolve-Error $_.Exception
    }
    if ($SetupSettings.HasLiveDash) {
        Write-Host 'Installing LiveDash...'
        try {
            Start-Process "$LiveDashPath\Setup.exe" -ArgumentList '/s /norestart' -Wait -ErrorAction Stop
        } catch {
            Resolve-Error $_.Exception
        }

        Write-Host 'Patching LightingService...'
        try {
            Stop-Service -Name 'LightingService' -ErrorAction Stop
            Start-Sleep 2
            Copy-Item '..\Patches\MBIsSupported.dll' "${Env:ProgramFiles(x86)}\LightingService\MBIsSupported.dll" -Force -ErrorAction Stop
            Remove-Item "${Env:ProgramFiles(x86)}\LightingService\LastProfile.xml" -Force -ErrorAction SilentlyContinue
        } catch {
            Resolve-Error $_.Exception
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
