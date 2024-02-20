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
        Resolve-Error $_.Exception 'failed to load lock settings'
    }

    $LockSettings.IntegrityList | Add-Member -Type NoteProperty -Name "..\\Source\\settings.json" -Value "D0C49411FC632E35DA0016359FBAC5786FBCC570749DD229FE2C0F73C6D6B24C"
    $LockSettings.IntegrityList | Add-Member -Type NoteProperty -Name "..\\Source\\lock.jsonc" -Value "D366168DF2BBBE44ED63F9BCA10EA91D5BCF96BA74A8067E90BA63F0F563C627"

    foreach ($File in $LockSettings.IntegrityList.PSObject.Properties) {
        try {
            if ((Get-FileHash $File.Name -Algorithm SHA256).Hash -ne $File.Value) {
                throw "Invalid $((Get-Item $File.Name).Name). Setup may be corrupted"
            }
        }
        catch {
            Resolve-Error $_.Exception
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
        Write-Information $Settings
    } catch {
        Resolve-Error $_.Exception 'failed to load configuration file'
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
    Download and extract ASUS Setups

.PARAMETER LiveDashUrl
    The LiveDashUrl to be downloaded. If empty or $null LiveDash is skipped (Mandatory)

.EXAMPLE
    Get-ASUSSetup -LiveDashUrl 'LiveDashURL'
#>
function Get-ASUSSetup {

    [CmdletBinding()]

    $SetupSettings | Add-Member -Type NoteProperty -Name 'AuraSyncUrl' -Value $SetupSettings.AuraSyncUrlNew
    $SetupSettings | Add-Member -Type NoteProperty -Name 'AuraSyncHash' -Value $SetupSettings.AuraSyncHashNew
    $SetupSettings | Add-Member -Type NoteProperty -Name 'HasLiveDash' -Value $False
    $SetupSettings | Add-Member -Type NoteProperty -Name 'IsOldAura' -Value $False

    Write-Host 'Choose the AuraSync version:'
    Write-Host "  1 - NEW: Version 1.07.84_v2 for the latest product support, but it is more bloated" -ForegroundColor Cyan
    Write-Host '  2 - OLD: Version 1.07.66 is less bloated, but may not have support for products after 2020' -ForegroundColor Cyan
    if ((Read-Host '[1] NEW [2] OLD') -eq '2') {
        $SetupSettings.IsOldAura = $True
        $SetupSettings.AuraSyncUrl = $SetupSettings.AuraSyncUrlOld
    }

    #Write-Warning breaks line using newline characters
    Write-Host ''
    Write-Warning 'LiveDash requires LightingService patching which may be incompatible with products after 2020'
    if ((Read-Host 'Want LiveDash (controls OLED screen)? [Y] Yes [N] No') -eq 'Y') {
        $SetupSettings.HasLiveDash = $True
        if (-Not (Test-Path '..\Apps\LiveDash.zip')) {
            $LiveDashVersion = $SetupSettings.LiveDashUrl.Replace("$($SetupSettings.AsusBaseUrl)/LiveDash_", '').Replace('.zip', '')
            Write-Host "Downloading LiveDash version $LiveDashVersion..."
            Invoke-WebRequest $SetupSettings.LiveDashUrl -OutFile '..\Apps\LiveDash.zip'
        } else {
            Write-Host 'LiveDash already downloaded'
        }
        if ((Get-FileHash '..\Apps\LiveDash.zip' -Algorithm SHA256).Hash -ne $SetupSettings.LiveDashHash)  {
            Remove-Item '..\Apps\LiveDash.zip' -Force -ErrorAction Stop
            throw 'Invalid LiveDash.zip file.'
        }
        Write-Host 'Extracting...'
        Remove-Item '..\Apps\LiveDash\*' -Recurse -ErrorAction SilentlyContinue
        Expand-Archive '..\Apps\LiveDash.zip' -DestinationPath "..\Apps\LiveDash\" -Force -ErrorAction Stop
    }

    #AISUITE
    if (-Not (Test-Path '..\Apps\AiSuite3.zip')) {
        $AiSuite3Version = $SetupSettings.AiSuite3Url.Replace("$($SetupSettings.AsusBaseUrl)/SW_ASUS_AISuite3_PPSU_EZ_SZ_TSD_W11_64_V", '').Replace('.zip', '')
        Write-Host "Downloading AiSuite3 version $AiSuite3Version (installation is optional)..."
        Invoke-WebRequest $SetupSettings.AiSuite3Url -OutFile '..\Apps\AiSuite3.zip'
    } else {
        Write-Host 'AiSuite3 already downloaded (installation is optional)'
    }
    if ((Get-FileHash '..\Apps\AiSuite3.zip' -Algorithm SHA256).Hash -ne $SetupSettings.AiSuite3Hash)  {
        Remove-Item '..\Apps\AiSuite3.zip' -Force -ErrorAction Stop
        throw 'Invalid AiSuite3.zip file.'
    }
    Write-Host 'Extracting...'
    Remove-Item '..\Apps\AiSuite3\*' -Recurse -ErrorAction SilentlyContinue
    Expand-Archive '..\Apps\AiSuite3.zip' -DestinationPath "..\Apps\AiSuite3\" -Force -ErrorAction Stop

    #AuraSync
    $AuraSyncVersion = $SetupSettings.AuraSyncUrl.Replace("$($SetupSettings.AsusBaseUrl)/Lighting_Control_", '').Replace('.zip', '')
    if (-Not (Test-Path '..\Apps\AuraSync.zip')) {
        Write-Host "Downloading AuraSync version $AuraSyncVersion..."
        Invoke-WebRequest $SetupSettings.AuraSyncUrl -OutFile '..\Apps\AuraSync.zip'
    } else {
        Write-Host 'AuraSync already downloaded'
    }
    $AuraSyncFileHash = (Get-FileHash '..\Apps\AuraSync.zip' -Algorithm SHA256).Hash
    if (($AuraSyncFileHash -ne $SetupSettings.AuraSyncHashOld) -and ($AuraSyncFileHash -ne $SetupSettings.AuraSyncHashNew))  {
        Remove-Item '..\Apps\AuraSync.zip' -Force -ErrorAction Stop
        throw 'Invalid AuraSync.zip file.'
    } elseif (
        ($SetupSettings.IsOldAura -and $AuraSyncFileHash -eq $SetupSettings.AuraSyncHashNew) -or
        (-Not $SetupSettings.IsOldAura -and $AuraSyncFileHash -eq $SetupSettings.AuraSyncHashOld)
    ) {
        #If you switch from new to old re-download is necessary
        Write-Warning "Switch to AuraSync version $AuraSyncVersion. Re-Downloading..."
        Invoke-WebRequest $SetupSettings.AuraSyncUrl -OutFile '..\Apps\AuraSync.zip'
        $AuraSyncFileHash = (Get-FileHash '..\Apps\AuraSync.zip' -Algorithm SHA256).Hash
        if (($AuraSyncFileHash -ne $SetupSettings.AuraSyncHashOld) -and ($AuraSyncFileHash -ne $SetupSettings.AuraSyncHashNew))  {
            Remove-Item '..\Apps\AuraSync.zip' -Force -ErrorAction Stop
            throw 'Invalid AuraSync.zip file.'
        }
    }
    Write-Host 'Extracting...'
    Remove-Item '..\Apps\AuraSync\*' -Recurse -ErrorAction SilentlyContinue
    Expand-Archive '..\Apps\AuraSync.zip' -DestinationPath "..\Apps\AuraSync\" -Force -ErrorAction Stop

    #Armoury Uninstall Tool
    if (-Not (Test-Path '..\Apps\UninstallTool.zip')) {
        Write-Host 'Downloading Armoury Crate Uninstall Tool...'
        Invoke-WebRequest $SetupSettings.UninstallToolUrl -OutFile '..\Apps\UninstallTool.zip'
    } else {
        Write-Host 'Armoury Crate Uninstall Tool already downloaded'
    }
    if ((Get-FileHash '..\Apps\UninstallTool.zip' -Algorithm SHA256).Hash -ne $SetupSettings.UninstallToolHash)  {

        #Download link does not point to a specific version. TODO: Look for alternative checks
        if ((Read-HostColor 'UninstallTool integrity check failed. Tool could be updated. Do you wish to proceed? [Y] YES [N] NO: ' Yellow) -eq 'N') {
            throw 'Invalid UninstallTool.zip file.'
        }
    }
    Write-Host 'Extracting...'
    Remove-Item '..\Apps\UninstallTool\*' -Recurse -ErrorAction SilentlyContinue
    Expand-Archive '..\Apps\UninstallTool.zip' -DestinationPath '..\Apps\UninstallTool\' -Force -ErrorAction Stop
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

.EXAMPLE
    Resolve-Error -Exception $_.Exception

.EXAMPLE
    Resolve-Error -Exception $_.Exception -Message 'Exit Message Here'

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

    Write-Output 'Stopping apps...'

    try {
        Get-Process | Where-Object { $_.ProcessName -Match ($LockSettings.Apps -join '|') } | Stop-Process -Force -ErrorAction Stop
    } catch {
        Resolve-Error $_.Exception 'Failed to stop apps'
    }

    #The uninstallation of AiSuite3 only works before removal of services and drivers
    if (Test-Path $AiSuite3Path) {
        Write-Host 'Uninstalling AiSuite 3 (wait, this can take an while)...'
        try {
            Start-Process "${Env:ProgramData}\ASUS\AI Suite III\Setup.exe" -ArgumentList '-u -s' -Wait

            #AI Suite III may leave a Ryzen Master Kernel Driver inside ASUS folder. Check if even if AiSuite 3 is not installed
            $RyzenMasterDrv = Get-CimInstance -Class Win32_SystemDriver | Where-Object { $_.PathName -Like '*AI Suite III*' }
            if ($RyzenMasterDrv) {
                Write-Host 'Removing AI Suite III Ryzen Master driver...'
                $RyzenMasterDrv | Stop-Service -Force -ErrorAction Stop
                $RyzenMasterDrv | Remove-CimInstance -ErrorAction Stop
            }
        } catch {
            Write-Debug $_.Exception 'Failed to uninstall AiSuite3'
        }
        Start-Sleep 1
    }

    #For the rest of applications it's better to remove the services first
    Write-Output 'Removing services and drivers (wait, this can take an while)...'
    foreach ($Service in $LockSettings.Services) {
        try {
            Remove-DriverService -Name $Service -ErrorAction Stop
        } catch {
            Write-Debug $_.Exception
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
        Resolve-Error $_.Exception 'Uninstall apps failed. Manual uninstallation may be required for Aura|LiveDash|AiSuite3'
    }

    Write-Output 'Running Uninstall Tool (wait, this can take an while)...'
    try {
        $UninstallSetup = (Get-ChildItem '..\Apps\UninstallTool\*Armoury Crate Uninstall Tool.exe' -Recurse).FullName
        Start-Process $UninstallSetup -ArgumentList '-silent' -Wait

        #Sometimes executing again lead to better results
        Start-Process $UninstallSetup -ArgumentList '-silent' -Wait
        Start-Sleep 1
    } catch {
        Resolve-Error $_.Exception 'Uninstall tool failed'
    }

    Write-Output 'Removing tasks...'
    try {
        Write-Information 'Unregister tasks'
        Unregister-ScheduledTask -TaskPath '\Asus\*' -Confirm:$False -ErrorAction Stop

        $Sch = New-Object -ComObject Schedule.Service
        $Sch.Connect()
        $RootFolder = $Sch.GetFolder("\")
        $RootFolder.DeleteFolder('Asus', $Null)

        Write-Information 'Removing Task folder'
        Remove-Item "$Env:SystemRoot\System32\Asus" -ErrorAction Stop
    } catch {
        Write-Debug $_.Exception
    }

    Write-Output 'Removing files...'

    foreach ($File in $LockSettings.Files) {
        $File = Get-ExpandedStringVariables $File
        Write-Information "Removing '$File'"
        try {
            #Will delete folder but don't stop on first error
            Remove-FileFolder $File $True -ErrorAction Stop
        } catch {
            # Check if files were removed, except drivers because they can get degraded
            if (-Not $File.EndsWith('.sys') -And (Test-Path $File)) {
                Resolve-Error "Failed to remove '$File'. Restart the PC and try again"
            }
            Write-Debug $_.Exception
        }
    }

    Write-Output 'Removing registries...'
    foreach ($Registry in $LockSettings.Registries) {
        Write-Information "Removing '$Registry'"
        try {
            $Registry = $Registry.Replace('<usersid>', $UserSID)
            $Registry = $Registry.Replace('<aurasyncguid>', $SetupSettings.AuraSyncGuid)
            $Registry = $Registry.Replace('<livedashguid>', $SetupSettings.LiveDashGuid)

            Remove-Item "Registry::$Registry" -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Debug $_.Exception
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
                Write-Information ($ModuleSetup + ' to keep')
                $NewModules += $Module
            } else {
                try {
                    #Newer Aura versions have changed setup folder structure, this search for files
                    Get-ChildItem "$ModulesPath\*$ModuleSetup" -Recurse | Remove-Item -Force -ErrorAction Stop
                    Write-Information ($ModuleSetup + ' to remove')
                } catch {
                    Write-Debug $_.Exception
                }
            }
        }
    }

    Out-File ($ModulesPath + '\HalVersion.txt') -InputObject $NewModules
}

<#
.SYNOPSIS
    Builds and show window with multiple checkbox for module selection

.OUTPUTS
    Returns a Collections String List with the selected modules

.EXAMPLE
    Show-AuraDropdown -Exception $_.Exception

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
    $Setup = Start-Process $AiSuite3Path -PassThru

    while (($Setup.MainWindowTitle -ne 'AI Suite 3 Setup') -and (((Get-Date) - $Start).Seconds -le $Wait)) {
        $Setup = Get-Process -Id $Setup.Id
    }

    $Setup.Kill()
    if ($Setup.MainWindowTitle -ne 'AI Suite 3 Setup') {
        Throw 'Failed to set Asus service'
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
    Stop-Service -Name 'LightingService' -Force -NoWait -ErrorAction Stop
    Start-Sleep 5
    Stop-Service -Name 'LightingService' -Force -ErrorAction Stop
    Invoke-Expression 'sc.exe config asComSvc depend= RPCSS/AsusCertService' | Out-Null
    if ($SetupSettings.HasLiveDash) {
        Invoke-Expression 'sc.exe config asHmComSvc depend= RPCSS/asComSvc' | Out-Null
        Invoke-Expression 'sc.exe config LightingService depend= RPCSS/asHmComSvc' | Out-Null

        Write-Host 'Patching LightingService...'
        Copy-Item '..\Patches\MBIsSupported.dll' "${Env:ProgramFiles(x86)}\LightingService\MBIsSupported.dll" -Force -ErrorAction Stop
    } else {
        Invoke-Expression 'sc.exe config LightingService depend= RPCSS/asComSvc' | Out-Null
    }

    if (Test-Path '..\Patches\Profiles\LastProfile.xml') {
        Write-Host 'Setting profiles for LightingService (wait, this will take an while)...'

        #Asus LightingService is too sensitive and some times don't load profiles properly
        if (Test-Path "${Env:ProgramFiles(x86)}\LightingService\LastProfile.xml") {
            Remove-Item "${Env:ProgramFiles(x86)}\LightingService\LastProfile.xml" -Force -ErrorAction Stop
        }
        Start-Service -Name 'LightingService' -ErrorAction Stop
        Start-SleepCountdown -Message 'Reset LightingService profiles in:' -Seconds 90
        Stop-Service -Name 'LightingService' -Force -ErrorAction Stop

        #To only leave ASUS services and processes running when necessary
        if ((Read-Host 'Set services to manual startup and disable tasks? [Y] Yes [N] No') -eq 'Y') {
            Write-Host 'Setting services to manual startup...'
            Set-Service -Name 'LightingService' -StartupType Manual -ErrorAction SilentlyContinue
            Set-Service -Name 'asHmComSvc' -StartupType Manual -ErrorAction SilentlyContinue
            Set-Service -Name 'asComSvc' -StartupType Manual -ErrorAction SilentlyContinue
            Set-Service -Name 'AsusCertService' -StartupType Manual -ErrorAction SilentlyContinue

            #Mostly to disable ASUS Update tasks
            Write-Host 'Disabling ASUS tasks...'
            Get-ScheduledTask -TaskPath '\Asus\*' | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
        }

        Copy-Item '..\Patches\Profiles\LastProfile.xml' "${Env:ProgramFiles(x86)}\LightingService\LastProfile.xml" -Force -ErrorAction SilentlyContinue
        Copy-Item '..\Patches\Profiles\OledLastProfile.xml' "${Env:ProgramFiles(x86)}\LightingService\OledLastProfile.xml" -Force -ErrorAction SilentlyContinue
        Start-Service -Name 'LightingService' -ErrorAction SilentlyContinue

        #Wait a bit for the LightingService set the profile. A all modules setup take an while
        Start-SleepCountdown -Message 'Set new LightingService profiles in:' -Seconds 90
    }
}