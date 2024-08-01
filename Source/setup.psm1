<# ================================ SETUP FUNCTIONS ================================ #>

<#
.SYNOPSIS
    Expand environment and execution context variables inside a string

.PARAMETER Value
    The value string to be expanded

.EXAMPLE
   Get-ExpandedStringVariables '%LOCALAPPDATA%\\$ContextVar'

.NOTES
    This function have to on the same module scope otherwise ExpandString won't work
#>
function Get-ExpandedStringVariables {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [String][AllowEmptyString()] $Value
    )

    if ($Value) {
        $Value = [System.Environment]::ExpandEnvironmentVariables($Value)
        $Value = $ExecutionContext.InvokeCommand.ExpandString($Value)
    }

    return $Value
}

<#
.SYNOPSIS
    Check file Setup Integrity

.EXAMPLE
    Compare-SetupIntegrity
#>
function Compare-SetupIntegrity {
    [CmdletBinding()]
    Param ()

    Write-Host 'Checking file integrity...'

    try {
        $Global:LockSettings = Get-Json '..\Source\lock.jsonc' -ErrorAction Stop
    } catch {
        Resolve-Error $_ 'failed to load lock settings'
    }

    $LockSettings.IntegrityList | Add-Member -Type NoteProperty -Name "..\\Source\\settings.json" -Value "F871C9A2D99C965103971395084BAF0A25781D103527D807F5B8F7FBEC3EF5A3"
    $LockSettings.IntegrityList | Add-Member -Type NoteProperty -Name "..\\Source\\lock.jsonc" -Value "AAA68EAFA9D8E00CC76D8FABD41E59BF24ACE9551B32F3CF96FAE258721814BE"

    foreach ($File in $LockSettings.IntegrityList.PSObject.Properties) {
        try {
            if ((Get-FileHash $File.Name -Algorithm SHA256).Hash -ne $File.Value) {
                throw "Invalid $((Get-Item $File.Name).Name). Setup may be corrupted"
            }
        }
        catch {
            Resolve-Error $_
        }
    }

    Clear-Host
}

<#
.SYNOPSIS
    Importe configuration from settings.json file to global variables

.EXAMPLE
    Import-Config

.NOTES
    The global variables created are:
    SetupSettings (JSON)
    UserSID
#>
function Import-Config {
    # Check Source integrity
    Compare-SetupIntegrity

    try {
        $Settings = Get-Json '..\Source\settings.json' -ErrorAction Stop
        Write-Log $Settings -Level 'INFO'
    } catch {
        Resolve-Error $_ 'failed to load configuration file'
    }

    $Global:SetupSettings = $Settings
    $Global:UserSID = Get-UserSID
}

<#
.SYNOPSIS
    Write to the console the application header ASCII Art Title

.EXAMPLE
    Write-HeaderTitle
#>
function Write-HeaderTitle {
    $VersionEmoji = Convert-UnicodeToEmoji '1F680'
    $AuthorEmoji = Convert-UnicodeToEmoji '1F4D1'

    #A empty space to avoid emoji corruption by POWERSHELL progress bar
    Write-Host "

    ___   _____ __  _______    _____      __                 ______            __
   /   | / ___// / / / ___/   / ___/___  / /___  ______     /_  __/___  ____  / /
  / /| | \__ \/ / / /\__ \    \__ \/ _ \/ __/ / / / __ \     / / / __ \/ __ \/ /
 / ___ |___/ / /_/ /___/ /   ___/ /  __/ /_/ /_/ / /_/ /    / / / /_/ / /_/ / /
/_/  |_/____/\____//____/   /____/\___/\__/\__,_/ .___/    /_/  \____/\____/_/
                                               /_/
  $AuthorEmoji author: codecrafting-io
  $VersionEmoji version: v$($SetupSettings.Version)
" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Intialize Asus Setup asking important questions
#>
function Initialize-AsusSetup {

    try {
        New-Item '..\Apps' -ItemType Directory -Force | Out-Null
    } catch {
        Resolve-Error $_ 'Failed to create folder "Apps"'
    }

    $SetupSettings | Add-Member -Type NoteProperty -Name 'UninstallOnly' -Value $True
    $SetupSettings | Add-Member -Type NoteProperty -Name 'HasAuraSync' -Value $False
    $SetupSettings | Add-Member -Type NoteProperty -Name 'IsOldAura' -Value $True
    $SetupSettings | Add-Member -Type NoteProperty -Name 'HasLightingService' -Value $False
    $SetupSettings | Add-Member -Type NoteProperty -Name 'HasLiveDash' -Value $False
    $SetupSettings | Add-Member -Type NoteProperty -Name 'HasAiSuite' -Value $False

    try {
        $HasPrevAiSuite = (Test-Path "${Env:ProgramFiles(x86)}\Asus\AI Suite III\AISuite3.exe" -ErrorAction Stop)
    } catch {
        Resolve-Error $_ 'Failed to initialize'
    }

    $SetupSettings | Add-Member -Type NoteProperty -Name 'HasPrevAiSuite' -Value $HasPrevAiSuite

    if ((Read-Host 'Only UNINSTALL apps?') -eq 'N') {
        $SetupSettings.UninstallOnly = $False
        Write-Host "`nChoose one AuraSync option:"
        Write-Host "  1 - NEW: Version 1.07.84_v2 for products launched until 2023, but it is more bloated" -ForegroundColor Cyan
        Write-Host '  2 - OLD: Version 1.07.66 is less bloated, but may not have support for products after 2020 (best for LiveDash)' -ForegroundColor Cyan
        Write-Host '  3 - Do NOT install AuraSync' -ForegroundColor Cyan

        switch((Read-Host '[1] NEW [2] OLD [3] Do NOT install')) {
            1 {
                $SetupSettings.HasAuraSync = $True
                $SetupSettings.IsOldAura = $False
                $SetupSettings.HasLightingService = $True
            }
            2 {
                $SetupSettings.HasAuraSync = $True
                $SetupSettings.HasLightingService = $True
            }
        }

        Write-Host ''
        Write-Warning 'LiveDash requires LightingService patching which may be incompatible with products after 2020'
        if ((Read-Host 'Want LiveDash (controls OLED screen)? [Y] Yes [N] No') -eq 'Y') {
            $SetupSettings.HasLiveDash = $True
            $SetupSettings.HasLightingService = $True
        }

        if ((Read-Host 'Install AiSuite 3? [Y] Yes [N] No') -eq 'Y') {
            $SetupSettings.HasAiSuite = $True
        }
    }
}

<#
.SYNOPSIS
    Download and extract ASUS Setups
#>
function Get-ASUSSetup {

    #Sometimes UninstallTool gets stuck
    Get-Process | Where-Object { $_.ProcessName -Match 'Uninstaller' } | Stop-Process -Force -ErrorAction Stop
    foreach ($Setup in $SetupSettings.Setups) {
        #Skip LiveDash
        if ($Setup.File -ne 'UninstallTool' -and $SetupSettings.UninstallOnly) {
            continue
        }
        if (($Setup.Name -eq 'LiveDash') -and (-not $SetupSettings.HasLiveDash)) {
            continue
        }
        $SetupFolder = "..\Apps\$($Setup.File)"
        $SetupFile = "$SetupFolder.zip"

        #Switch settings when using the old aura sync
        if ($Setup.Name -eq 'Aura Sync' -and $SetupSettings.IsOldAura) {
            $Setup.Url = $Setup.OldAuraUrl
            $Setup.Version = $Setup.OldAuraVersion
            $Setup.Hash = $Setup.OldAuraHash
            $SetupFile = "$SetupFolder.old.zip"
        }

        #Construct final URL
        $Setup.Url = "$($SetupSettings.AsusBaseUrl)/$($Setup.Url)"

        #Download
        if (-Not (Test-Path $SetupFile)) {
            Write-Host "Downloading $($Setup.Name) version $($Setup.Version)..."
            Invoke-WebRequest $Setup.Url -OutFile $SetupFile
        } else {
            Write-Host "$($Setup.Name) already downloaded"
        }

        #Check Hash.
        #TODO: Improve this check. I know this IF is too bloated, but this is just to not repeat the steps.
        $FileHash = (Get-FileHash $SetupFile -Algorithm SHA256).Hash
        if (
            $FileHash -eq $Setup.Hash -or
            (
                ($Setup.File -eq 'UninstallTool') -and
                ((Read-HostColor 'UninstallTool integrity check failed. Tool could be updated. Wish to proceed? [Y] YES [N] NO: ' Yellow) -eq 'Y')
            )
        ) {
            Write-Host 'Extracting...'
            Remove-Item "$SetupFolder\*" -Recurse -ErrorAction SilentlyContinue
            Expand-Archive $SetupFile -DestinationPath "$SetupFolder\" -Force -ErrorAction Stop
        } else {
            Remove-Item $SetupFile -Force -ErrorAction Stop
            throw "Invalid $($Setup.Name) file."
        }
    }
}

<#
.SYNOPSIS
    Clear, Uninstall, Removes, Delete, Purge and Nuke Asus Bloatware

.PARAMETER Exception
    The Exception to be handle (mandatory)

.PARAMETER Message
    Optional exit message

.INPUTS
    Description of objects that can be piped to the script.

.OUTPUTS
    Description of objects that are output by the script.

.LINK
    Links to further documentation.

.NOTES
    Detail on what the script does, if this is needed.
#>
function Clear-AsusBloat {

    [CmdletBinding()]
    PARAM()

    $AuraUninstaller = "${Env:ProgramFiles(x86)}\InstallShield Installation Information\$($SetupSettings.AuraSyncGuid)"
    $LiveDashUninstaller = "${Env:ProgramFiles(x86)}\InstallShield Installation Information\$($SetupSettings.LiveDashGuid)"
    $AiSuite3Path = "${Env:ProgramFiles(x86)}\Asus\AI Suite III\AISuite3.exe"
    $GlckIODriver = "${Env:ProgramData}\Package Cache\$($SetupSettings.GlckIODriverGuid)\GlckIODrvSetup.exe"

    Write-Host 'Stopping apps...'
    try {
        Get-Process | Where-Object { $_.ProcessName -Match ($LockSettings.Apps -join '|') } | Stop-Process -Force -ErrorAction Stop
    } catch {
        Resolve-Error $_ 'Failed to stop apps'
    }
    Start-Sleep 1

    #The uninstallation of AiSuite3 only works before removal of services and drivers
    try {
        if (Test-Path $AiSuite3Path) {
            Write-Host 'Uninstalling AiSuite 3 (wait, this may take a while)...'
            Start-Process "${Env:ProgramData}\ASUS\AI Suite III\Setup.exe" -ArgumentList '-u -s' -Wait -ErrorAction Stop

            #AI Suite III may leave a Ryzen Master Kernel Driver inside ASUS folder. Check if even if AiSuite 3 is not installed
            $RyzenMasterDrv = Get-CimInstance -Class Win32_SystemDriver | Where-Object { $_.PathName -Like '*AI Suite III*' }
            if ($RyzenMasterDrv) {
                Write-Host 'Removing AI Suite III Ryzen Master driver...'
                $RyzenMasterDrv | Stop-Service -Force -ErrorAction Stop
                $RyzenMasterDrv | Remove-CimInstance -ErrorAction Stop
            }
        }
        Start-Sleep 1
    } catch {
        Resolve-Error $_ 'Failed to uninstall AiSuite3'
    }

    #For the rest of applications it's better to remove the services first
    Write-Host 'Removing services (wait, this may take a while)...'
    foreach ($Service in $LockSettings.Services) {
        try {
            Remove-DriverService -Name $Service -ErrorAction Stop
        } catch {
            Resolve-Error $_ "Failed to remove service '$Service'. Reboot and/or try again"
        }
    }

    Write-Host 'Removing drivers (wait, this may take a while)...'
    foreach ($Driver in $LockSettings.Drivers) {
        try {
            Remove-DriverService -Name $Driver -ErrorAction Stop
        } catch {
            Write-Log $_ -Level 'DEBUG' -ErrorAction SilentlyContinue
        }
    }

    try {
        if (Test-Path $LiveDashUninstaller) {
            Write-Host 'Uninstalling LiveDash...'

            #InstallShield Setup.exe is missing after silent install.
            Copy-Item '.\Bin\Setup.exe' "$LiveDashUninstaller\Setup.exe" -Force -ErrorAction Stop
            Copy-Item '..\Source\uninstall-livedash.iss' "$LiveDashUninstaller\uninstall.iss" -Force -ErrorAction Stop
            Start-Process "$LiveDashUninstaller\Setup.exe" -ArgumentList "-l0x9 -x -s -ARP -f1`"$LiveDashUninstaller\uninstall.iss`"" -Wait
            Start-Sleep 1
        }
        if (Test-Path $AuraUninstaller) {
            Write-Host 'Uninstalling AuraSync...'

            #InstallShield Setup.exe is missing after silent install.
            Copy-Item '.\Bin\Setup.exe' "$AuraUninstaller\Setup.exe" -Force -ErrorAction Stop
            Copy-Item '..\Source\uninstall-aurasync.iss' "$AuraUninstaller\uninstall.iss" -Force -ErrorAction Stop
            Start-Process "$AuraUninstaller\Setup.exe" -ArgumentList "-l0x9 -x -s -ARP -f1`"$AuraUninstaller\uninstall.iss`"" -Wait
            Start-Sleep 1
        }
        if (Test-Path $GlckIODriver) {
            Write-Host 'Uninstalling GlckIO2...'

            Start-Process $GlckIODriver -ArgumentList '/uninstall /quiet' -Wait
            Start-Process "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/x $GlckIOD2riverGuid /quiet" -Wait
            Start-Sleep 1
        }
    } catch {
        #In case of error manual uninstallation is required here
        Resolve-Error $_ 'Uninstall apps failed. Manual uninstallation may be required for Aura|LiveDash|AiSuite3'
    }

    Write-Host 'Running Uninstall Tool (wait, this may take a while)...'
    try {
        $UninstallSetup = (Get-ChildItem '..\Apps\UninstallTool\*Armoury Crate Uninstall Tool.exe' -Recurse).FullName
        Start-Process $UninstallSetup -ArgumentList '-silent' -Wait

        #Sometimes executing again lead to better results
        Start-Process $UninstallSetup -ArgumentList '-silent' -Wait
        Start-Sleep 1
    } catch {
        Resolve-Error $_ 'Uninstall tool failed'
    }

    Write-Host 'Removing tasks...'
    try {
        Write-Log 'Unregister tasks' -Level 'INFO'
        Unregister-ScheduledTask -TaskPath '\Asus\*' -Confirm:$False -ErrorAction Stop

        $Sch = New-Object -ComObject Schedule.Service
        $Sch.Connect()
        $RootFolder = $Sch.GetFolder("\")
        $RootFolder.DeleteFolder('Asus', $Null)

        Write-Log 'Removing Task folder' -Level 'INFO'
        Remove-Item "$Env:SystemRoot\System32\Asus" -ErrorAction Stop
    } catch {
        Write-Log $_ -Level 'ERROR' -OutputHost $False -ErrorAction SilentlyContinue
    }

    Write-Host 'Removing files...'

    foreach ($File in $LockSettings.Files) {
        $File = Get-ExpandedStringVariables $File

        #First stop any handles holding the file
        try {
            Close-FileHandles $File
            Start-Sleep 1
        } catch {
            Write-Log $_ -Level 'ERROR' -OutputHost $False -ErrorAction SilentlyContinue
        }

        #Then remove the file
        try {
            Write-Log "Removing '$File'" -Level 'INFO' -ErrorAction SilentlyContinue
            #Will delete folder but don't stop on first error
            Remove-FileFolder $File $True -ErrorAction Stop
        } catch [System.Management.Automation.ItemNotFoundException] {
            Write-Log "File '$File' not found" -Level 'DEBUG' -ErrorAction SilentlyContinue
        } catch {
            # Check if files were removed, except drivers because they can get degraded
            if (-Not $File.EndsWith('.sys') -And (Test-Path $File)) {
                Resolve-Error $_ "Failed to remove '$File'. Reboot and try again"
            }
            Write-Log $_ -Level 'ERROR' -OutputHost $False -ErrorAction SilentlyContinue
        }
    }

    Write-Host 'Removing registries...'
    foreach ($Registry in $LockSettings.Registries) {
        Write-Log "Removing '$Registry'" -Level 'INFO' -ErrorAction SilentlyContinue
        try {
            $Registry = $Registry.Replace('<usersid>', $UserSID)
            $Registry = $Registry.Replace('<aurasyncguid>', $SetupSettings.AuraSyncGuid)
            $Registry = $Registry.Replace('<livedashguid>', $SetupSettings.LiveDashGuid)

            Remove-Item "Registry::$Registry" -Recurse -Force -ErrorAction Stop
        } catch [System.Management.Automation.ItemNotFoundException] {
            Write-Log "Registry '$Registry' not found" -Level 'DEBUG' -ErrorAction SilentlyContinue
        } catch {
            Write-Log $_ -Level 'ERROR' -OutputHost $False -ErrorAction SilentlyContinue
        }
    }

    Start-Process '.\Bin\AuraCleaner.exe' -Wait | Out-Null
}

<#
.SYNOPSIS
    Update and patch AuraModules. A dropdown for module selection is shown

.PARAMETER ModulesPath
    The path where the AuraSync modules are. (Mandatory)

.EXAMPLE
    Update-AuraModules -ModulesPath 'ModulesPath'

.NOTES
    If HasLiveDash is $True and none of AacMBSetup.exe, AacDisplaySetup.exe AacAIOFanSetup.exe modules were selected AacMBSetup is added
#>
function Update-AuraModules {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $ModulesPath
    )

    $Modules = Get-Content '..\Source\HalVersion.txt'
    $SelectedMap = Show-AuraDropdown

    #All this just to show friendly names for the user
    Write-Host 'Modules to be installed:' -NoNewline
    $Selected = New-Object System.Collections.Generic.List[String]
    foreach ($Key in $SelectedMap.Keys) {
        Write-Host " '$($SelectedMap[$Key])'" -NoNewline -ForegroundColor Yellow
        $Key.Split('-') | ForEach-Object { $Selected.Add($_) | Out-Null }
    }
    Write-Host ''

    # Mandatory modules
    $Selected.Add('AuraServiceSetup.exe')
    if ($SetupSettings.HasLiveDash -and -not ($Selected.Contains('AacMBSetup.exe') -or $Selected.Contains('AacDisplaySetup.exe') -or $Selected.Contains('AacAIOFanSetup.exe'))) {
        $Selected.Add('AacMBSetup.exe')
    }

    $NewModules = @()
    foreach ($Module in $Modules) {
        #Skip blank lines
        if ($Module.Length -gt 0) {
            $ModuleSetup = ($Module.Substring(10, $Module.IndexOf("]'s") - 10))
            if ($Selected.Contains($ModuleSetup)) {
                Write-Log "$ModuleSetup to keep" -Level 'INFO' -ErrorAction SilentlyContinue
                $NewModules += $Module
            } else {
                try {
                    #Newer Aura versions have changed setup folder structure, this search for files
                    Get-ChildItem "$ModulesPath\*$ModuleSetup" -Recurse | Remove-Item -Force -ErrorAction Stop
                    Write-Log "$ModuleSetup to remove" -Level 'INFO' -ErrorAction SilentlyContinue
                } catch {
                    Write-Log $_ -Level 'DEBUG' -ErrorAction SilentlyContinue
                }
            }
        }
    }

    Out-File "$ModulesPath\HalVersion.txt" -InputObject $NewModules
}

<#
.SYNOPSIS
    Builds and show window with multiple checkbox for module selection

.OUTPUTS
    Returns a Collections String List with the selected modules

.EXAMPLE
    Show-AuraDropdown

.NOTES
    Detail on what the script does, if this is needed.
#>
function Show-AuraDropdown {
    [void] [System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')
    [void] [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')

    $Form = New-Object System.Windows.Forms.Form
    $Form.Size = New-Object System.Drawing.Size(350,250)
    $Form.text = 'Choose AuraSync modules'
    $LabelFont = New-Object System.Drawing.Font('Segoe UI', 10)

    $GroupBox = New-Object System.Windows.Forms.GroupBox
    $GroupBox.Location = New-Object System.Drawing.Size(($Form.Size.Width - 50), 20)
    $GroupBox.Left = 10
    $GroupBox.Top = 5
    $GroupBox.Text = 'AuraSync modules'
    $GroupBox.Font = $LabelFont
    $Form.Controls.Add($GroupBox)

    $Options = $LockSettings.AuraModules.PSObject.Properties
    if (-Not $SetupSettings.IsOldAura) {
        #Does exist for the new Aura Sync
        $Options.Remove('AacCorsairSetup.exe')
        $Options.Remove('AacGalaxSetup.exe')
    } else {
        #Does exist for the old Aura Sync
        $Options.Remove('aacsetup_jmi_1.0.5.1.exe')
        $Options.Remove('AacSetup_WD_Black_AN1500_v1.0.12.0.exe-AacSetup_WD_BLACK_D50_1.0.9.0.exe')
    }

    $Checkboxes = @()
    $Y = 20

    foreach ($Option in $Options) {
        $Checkbox = New-Object System.Windows.Forms.CheckBox
        $Checkbox.Name = $Option.Name
        $Checkbox.Text = $Option.Value
        $Checkbox.Location = New-Object System.Drawing.Size(10, $Y)
        $Checkbox.Size = New-Object System.Drawing.Size(($Form.Size.Width - 70), 20)
        $Checkbox.Font = $LabelFont
        $GroupBox.Controls.Add($Checkbox)
        $Checkboxes += $Checkbox
        $Y += 30
    }

    $GroupBox.Size = New-Object System.Drawing.Size(($Form.Size.Width - 50), ($y + 50))
    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Size(10, $y)
    $closeButton.Size = New-Object System.Drawing.Size(($Form.Size.Width - 70), 35)
    $closeButton.Text = 'CONFIRM'
    $closeButton.BackColor = '#145A99'
    $closeButton.ForeColor = '#FFFFFF'
    $closeButton.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
    $closeButton.Add_Click({ $Form.Close() })
    $GroupBox.Controls.Add($closeButton)

    $Form.Size = New-Object System.Drawing.Size(350, ($Y + 120))
    $Form.ShowDialog() | Out-Null

    #Just to show friendly names to the user!
    $Result = [ordered]@{}
    foreach ($Checkbox in $Checkboxes) {
        if ($Checkbox.Checked) {
            $Result[$Checkbox.Name] = $Checkbox.Text
        }
    }

    #Prevents pipe to cast HashTable to Object
    return ,$Result
}

<#
.SYNOPSIS
    Install ASUS Com and ASUS Cert Service

.PARAMETER AiSuite3Path
    THe AiSuite 3 setup path

.PARAMETER Wait
    The max amount of time in seconds to the AiSuite 3 window shows up

.EXAMPLE
    Set-AsusService -AiSuite3Path 'AiSuite3Path'

.EXAMPLE
    Set-AsusService -AiSuite3Path 'AiSuite3Path' -Wait 5

.NOTES
    Throws a exception if surpass the max amount of time defined by $Wait
#>
function Set-AsusService {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $AiSuite3Path,

        [Parameter()]
        [double] $Wait = 10
    )

    Write-Host 'Set ASUS basic services and drivers through AiSuite3 quick setup...'
    $Start = Get-Date
    $AiSuite3Title = 'AI Suite 3 Setup'
    $Setup = $null

    try {
        $Setup = Start-Process $AiSuite3Path -PassThru -ErrorAction Stop
    } catch {
        Write-Log $_ -Level 'DEBUG' -ErrorAction SilentlyContinue
    }

    #This will wait for the window to launch, so not a normal wait
    while ($Setup -And ($Setup.MainWindowTitle -ne $AiSuite3Title) -And (((Get-Date) - $Start).Seconds -le $Wait)) {
        #This will search instead of get the process to avoid exceptions.
        #Look for programs with the matched title may help in edge cases of $Setup.Id is null
        $Setup = (Get-Process | Where-Object { $_.Id -eq $Setup.Id -or $_.MainWindowTitle -eq $AiSuite3Title } | Select-Object -First 1)
    }

    if ($Setup -And -Not $Setup.HasExited) {
        $Setup.Kill()
        if ($Setup.MainWindowTitle -ne $AiSuite3Title) {
            Throw 'Failed to set ASUS basic services. AiSuite3 quick setup did not respond in time'
        }
    } else {
        Throw 'Failed to set ASUS basic services. AiSuite3 quick setup failed to launch'
    }
}

<#
.SYNOPSIS
    Update ASUS Service post setup

.EXAMPLE
    Update-AsusService

.NOTES
    If a local LastProfile exists will update the profile and set the services to manual startup and disable all ASUS Tasks
#>
function Update-AsusService {

    if (-not (Test-Path "${Env:ProgramFiles(x86)}\LightingService")) {
        throw 'Failed to install LightingService. Reboot and try again'
    }

    #Bring some sense to this madness
    Write-Host 'Updating services dependencies...'
    Invoke-Expression 'sc.exe config asComSvc depend= RPCSS/AsusCertService' | Out-Null
    if ($SetupSettings.HasLiveDash) {
        Invoke-Expression 'sc.exe config asHmComSvc depend= RPCSS/asComSvc' | Out-Null
        Invoke-Expression 'sc.exe config LightingService depend= RPCSS/asHmComSvc' | Out-Null

        Stop-Service -Name 'LightingService' -Force -NoWait -ErrorAction SilentlyContinue
        Start-Sleep 10
        Stop-Service -Name 'LightingService' -Force -ErrorAction Stop

        Write-Host 'Patching LightingService...'
        Copy-Item '..\Patches\MBIsSupported.dll' "${Env:ProgramFiles(x86)}\LightingService\MBIsSupported.dll" -Force -ErrorAction Stop
    } else {
        Invoke-Expression 'sc.exe config LightingService depend= RPCSS/asComSvc' | Out-Null
    }

    if (Test-Path '..\Patches\Profiles\LastProfile.xml') {
        Write-Host 'Setting profiles for LightingService...'

        #Asus LightingService is too sensitive and some times don't load profiles properly
        if (Test-Path "${Env:ProgramFiles(x86)}\LightingService\LastProfile.xml") {
            Remove-Item "${Env:ProgramFiles(x86)}\LightingService\LastProfile.xml" -Force -ErrorAction Stop
        }
        Start-Service -Name 'LightingService' -ErrorAction Stop
        Start-SleepCountdown -Message 'Reset LightingService profiles in:' -Seconds 90
        Stop-Service -Name 'LightingService' -Force -ErrorAction Stop

        Copy-Item '..\Patches\Profiles\LastProfile.xml' "${Env:ProgramFiles(x86)}\LightingService\LastProfile.xml" -Force -ErrorAction SilentlyContinue
        Copy-Item '..\Patches\Profiles\OledLastProfile.xml' "${Env:ProgramFiles(x86)}\LightingService\OledLastProfile.xml" -Force -ErrorAction SilentlyContinue
        Start-Service -Name 'LightingService' -ErrorAction SilentlyContinue

        #Wait a bit for the LightingService set the profile. A all modules setup take an while
        Start-SleepCountdown -Message 'Set new LightingService profiles in:' -Seconds 90
        Write-Host ''
        Write-Warning "Drivers may need to be started manually before applications and services, otherwise they won't work."
        Write-Warning "Use this to have the absolute minimum number of processes running"

        #This option is mainly intended for advanced users
        if ((Read-Host 'Let ASUS drivers start with Windows? [Y] Yes [N] No') -eq 'N') {
            Write-Host "Setting drivers to manual startup..."
            foreach ($Driver in $LockSettings.Drivers) {
                Write-Log "Setting driver '$Driver' to manual startup" -Level 'INFO' -ErrorAction SilentlyContinue
                try {
                    Set-Service -Name $Driver -StartupType Manual -ErrorAction Stop
                } catch {
                    Write-Log $_ -Level 'DEBUG' -ErrorAction SilentlyContinue
                }
            }
        }
    }

    #To only leave ASUS services and processes running when necessary
    if ((Read-Host 'Let ASUS services and tasks to start with Windows? [Y] Yes [N] No') -eq 'N') {
        Write-Host "Setting services to manual startup..."
        foreach ($Service in $LockSettings.Services) {
            Write-Log "Setting service '$Service' to manual startup" -Level 'INFO' -ErrorAction SilentlyContinue
            try {
                Set-Service -Name $Service -StartupType Manual -ErrorAction Stop
            } catch {
                Write-Log $_ -Level 'DEBUG' -ErrorAction SilentlyContinue
            }
        }

        #Mostly to disable ASUS Update tasks
        Write-Host 'Disabling ASUS tasks...'
        Get-ScheduledTask -TaskPath '\Asus\*' | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
    }
}
