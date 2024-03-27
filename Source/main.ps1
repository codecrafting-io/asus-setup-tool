#$global:DebugPreference = 'Continue'
#Requires -RunAsAdministrator

#Change PS UI language for consistent support while there is no internationalization support
[System.Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
Import-Module .\utils.psm1
Import-Module .\setup.psm1

<# ======================================== MAIN SCRIPT ======================================== #>


#********************************************
# INITIALIZATION STEP
#********************************************

Import-Config
Write-HeaderTitle
Write-Log 'INIT ASUS SETUP' -HostColor 'Green' -ErrorAction Stop
Initialize-AsusSetup



#********************************************
# GET ASUS SETUP STEP
#********************************************

Write-Host ''
Write-Log 'GET ASUS SETUP' -HostColor 'Green' -ErrorAction Stop
try {
    Get-ASUSSetup -ErrorAction Stop
} catch {
    Resolve-Error $_ 'Failed to get AsusSetup. Try again'
}



#********************************************
# CLEAR ASUS BLOATWARE STEP
#********************************************

Write-Host ''
Write-Log 'CLEAR ASUS BLOATWARE' -HostColor 'Green' -ErrorAction Stop
Clear-AsusBloat

if (-Not $SetupSettings.UninstallOnly) {

    #********************************************
    # PATCH ASUS SETUP STEP
    #********************************************

    Write-Host ''
    Write-Log 'PATCH ASUS SETUP' -HostColor 'Green' -ErrorAction Stop
    Write-Host 'Patching AiSuite3 setup...'
    try {
        Copy-Item '..\Patches\AiSuite3\DrvResource\*' '..\Apps\AiSuite3\DrvResource' -Recurse -Force -ErrorAction Stop
    } catch {
        Resolve-Error $_
    }

    if ($SetupSettings.HasLightingService) {
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
            $ChooseModules = Read-Host 'Select which AuraSync modules to install? [Y] Yes [N] No'
            if ($ChooseModules -eq 'Y') {
                Write-Host 'Updating AuraSync modules...'
                Update-AuraModules $AuraModulesPath -ErrorAction Stop
            }
        } catch {
            Resolve-Error $_
        }

        if ($SetupSettings.HasLiveDash) {
            Write-Host 'Patching LiveDash...'
            try {
                $LiveDashPath = (Resolve-Path '..\Apps\LiveDash\*').Path
                Remove-Item "$LiveDashPath\LightingService" -Recurse -Force -ErrorAction Stop
                Copy-Item '..\Patches\AiSuite3\DrvResource\AXSP\*' "$LiveDashPath\AXSP" -Recurse -Force -ErrorAction Stop
                Copy-Item "$AuraPath\LightingService" $LiveDashPath -Recurse -Force -ErrorAction Stop
            } catch {
                Resolve-Error $_
            }
        }
    }



    #********************************************
    # INSTALL ASUS SETUP STEP
    #********************************************

    Write-Host ''
    Write-Log 'INSTALL ASUS SETUP' -HostColor 'Green' -ErrorAction Stop
    try {
        Set-AsusService (Resolve-Path '..\Apps\AiSuite3\Setup.exe').Path -Wait 15
        Start-Sleep 5
    } catch {
        Resolve-Error $_
    }

    if ($SetupSettings.HasAuraSync) {
        Write-Host 'Installing Aura Sync...'
        try {
            Start-Process "$AuraPath\Setup.exe" -ArgumentList '/s /norestart' -Wait
            Start-Sleep 2
        } catch {
            Resolve-Error $_
        }
    }

    if ($SetupSettings.HasLiveDash) {
        Write-Host 'Installing LiveDash...'
        try {
            Start-Process "$LiveDashPath\Setup.exe" -ArgumentList '/s /norestart' -Wait -ErrorAction Stop
            Start-Sleep 2
        } catch {
            Resolve-Error $_
        }
    }

    if ($SetupSettings.HasAiSuite) {
        if ($SetupSettings.HasPrevAiSuite) {
            Write-Warning 'Reboot is required after AiSuite3 uninstallation. Install manually later on folder "Apps\AiSuite3"'
        } else {
            Write-Host 'Installing AiSuite 3...'
            try {
                Start-Process '..\Apps\AiSuite3\AsusSetup.exe' -ArgumentList '/s /norestart' -Wait
                Start-Sleep 2
            } catch {
                Resolve-Error $_
            }
        }
    }

    if ($SetupSettings.HasLightingService) {
        try {
            Update-AsusService
        } catch {
            Resolve-Error $_
        }
    }
}

Write-Host 'Removing temp files...'
Remove-FileFolder $Env:TEMP -ErrorAction SilentlyContinue



#********************************************
# ASUS SETUP END
#********************************************

Write-Log "ASUS SETUP FINISHED" -OutputHost $False -CloseWriter -ErrorAction SilentlyContinue
$Emoji = Convert-UnicodeToEmoji '1F389'
Write-Host "`n$Emoji ASUS SETUP TOOL FINISHED WITH SUCCESS! $Emoji" -ForegroundColor Green
if ((Read-Host 'Reboot system now (recommended)? [Y] Yes [N] No') -eq 'Y') {
    shutdown /r /t 5 /c "System will reboot"
}
