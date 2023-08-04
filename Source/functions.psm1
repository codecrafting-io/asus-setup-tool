<# ================================ FUNCTIONS ================================ #>

<#
.SYNOPSIS
    Resolves error exit strategy

.PARAMETER Exception
    The Exception to be handle (mandatory)

.PARAMETER Message
    Optional exit message

.EXAMPLE
    Resolve-Error -Exception $_.Exception

.EXAMPLE
    Resolve-Error -Exception $_.Exception -Message 'Exit Message Here'
#>
function Resolve-Error {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [Exception] $Exception,

        [String] $Message
    )

    Write-Debug $Exception
    Write-Host "`n$($Exception.Message)" -ForegroundColor Red
    Write-Host "`n$Message" -ForegroundColor Red
    Read-Host -Prompt "Press [ENTER] to exit"

    Exit
}

<#
.SYNOPSIS
    Converts unicode string to Int32 system emoji

.PARAMETER Unicode
The unicode string. Cannot be null or empty

.OUTPUTS
    The converted string emoji

.EXAMPLE
    Convert-UnicodeToEmoji -Unicode '1F389'
#>
function Convert-UnicodeToEmoji {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $Unicode
    )

    return [System.Char]::ConvertFromUtf32([System.Convert]::toInt32($Unicode, 16))
}

<#
.SYNOPSIS
    Importe configuration from settings.json file to global variables

.EXAMPLE
    Import-Config

.NOTES
    The global variables created are:
    AsusSetupToolVersion
    AuraSyncUrl
    AiSuite3Url
    LiveDashUrl
    UninstallToolUrl
    AuraSyncGuid
    LiveDashGuid
    GlckIODriverGuid
    GlckIO2DriverGuid
    UserSID
#>
function Import-Config {

    try {
        $Settings = Get-Content -Raw '..\Source\settings.json' | ConvertFrom-Json -ErrorAction Stop
        Write-Information $Settings
    } catch {
        Resolve-Error $_.Exception 'failed to load configuration file'
    }

    $Global:AsusSetupToolVersion = $Settings.version
    $Global:AuraSyncUrl = $Settings.AuraSyncUrl
    $Global:AiSuite3Url = $Settings.AiSuite3Url
    $Global:LiveDashUrl = $Settings.LiveDashUrl
    $Global:UninstallToolUrl = $Settings.UninstallToolUrl
    $Global:AuraSyncGuid = $Settings.AuraSyncGuid
    $Global:LiveDashGuid = $Settings.LiveDashGuid
    $Global:GlckIODriverGuid = $Settings.GlckIODriverGuid
    $Global:GlckIO2DriverGuid = $Settings.GlckIO2DriverGuid
    $Global:UserSID = Get-UserSID
}

<#
.SYNOPSIS
    Write to the console the application header ASCII Art Title

.EXAMPLE
    Write-HeaderTitle
#>
function Write-HeaderTitle {
    $Emoji = Convert-UnicodeToEmoji '1F680'
    Write-Host "
    ___   _____ __  _______    _____      __                 ______            __
   /   | / ___// / / / ___/   / ___/___  / /___  ______     /_  __/___  ____  / /
  / /| | \__ \/ / / /\__ \    \__ \/ _ \/ __/ / / / __ \     / / / __ \/ __ \/ /
 / ___ |___/ / /_/ /___/ /   ___/ /  __/ /_/ /_/ / /_/ /    / / / /_/ / /_/ / /
/_/  |_/____/\____//____/   /____/\___/\__/\__,_/ .___/    /_/  \____/\____/_/
                                               /_/
    version: $Emoji $AsusSetupToolversion $Emoji
    author: CodeCrafting-io
    " -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Check whether current system is Windows 11 or not

.OUTPUTS
    Returns $True or $False if current system is Windows 11 or not

.EXAMPLE
    Get-IsWindows11
#>
function Get-IsWindows11 {
    $BuildVersion = $([System.Environment]::OSVersion.Version.Build)
    if ($BuildVersion -ge '22000') {
        return $True
    }

    return $False
}

<#
.SYNOPSIS
    Remove Folder and its contents. If some file could not be deleted the script continues to next file

.PARAMETER Path
    The Path file string to be removed (mandatory)

.PARAMETER RemoveContainer
    Remove the folder container. This is $False by default

.EXAMPLE
    Remove-FileFolder -Path 'File Path'

.EXAMPLE
    Remove-FileFolder -Path 'File Path' -RemoveContainer $True

.NOTES
    Only the last error is thrown
#>
function Remove-FileFolder {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $Path,

        [bool] $RemoveContainer = $False
    )

    $Files = Get-ChildItem $Path -Recurse
    $LastException = $null
    foreach ($File in $Files) {
        try {
            Remove-Item $File.FullName -Force -Recurse -ErrorAction Stop
        } catch {
            $LastException = $_.Exception
        }
    }
    if ($RemoveContainer) {
        Remove-Item -Path $Path -Force -Recurse
    }
    if ($LastException) {
        throw $LastException
    }
}

<#
.SYNOPSIS
    Prints a colored string to the console before a empty ReadHost

.PARAMETER Message
The message to be printed (mandatory)

.PARAMETER ForegroundColor
The color of the message (mandatory)

.EXAMPLE
    Read-HostColor -Message 'Message' -ForegroundColor Green
#>
function Read-HostColor {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String] $Message,

        [Parameter(Mandatory)]
        [String] $ForegroundColor
    )

    Write-Host $Message -ForegroundColor $ForegroundColor
    Read-Host
}


<#
    Copy Item showing a progress. Returns true if successfull or throw an exception if failed
#>
<#
.SYNOPSIS
    Copy Item showing a progress.

.PARAMETER Source
    The source path to be copied (Mandatory)

.PARAMETER Target
    The target path to be copied (Mandatory)

.PARAMETER Message
    The actitivy message (Mandatory)

.PARAMETER ShowFileProgress
    Shows amount of progress of files copied (optional). Default is $True

.PARAMETER ShowFiles
    Shows the files beign copied (optional). Default is $False

.OUTPUTS
    Returns a Object with the information about the copy if successfull or throw a exception if failed

.EXAMPLE
    Copy-ItemWithProgress -Source 'Source' -Target 'Target' -Message 'Message'

.EXAMPLE
    Copy-ItemWithProgress -Source 'Source' -Target 'Target' -Message 'Message' -ShowFileProgress $False -ShowFiles $True
#>
function Copy-ItemWithProgress
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $Source,

        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $Target,

        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $Message,

        [bool] $ShowFileProgress = $True,

        [bool] $ShowFiles = $False
    )

    $startTime = Get-Date

    if ($Source.Length -lt 2) {
        Throw "source path '$Source' is invalid"
    } elseif ($Source[$Source.Length - 1] -eq "\") {
        $Source = $Source.Substring(0, $Source.Length - 1)
    }

    if ($Target.Length -lt 2) {
        Throw "target path '$Target' is invalid"
    } elseif ($Target[$Target.Length - 1] -eq "\") {
        $Target = $Target.Substring(0, $Target.Length - 1)
    }

    $FileList = Get-ChildItem "$Source" -Recurse
    $SourceFullpath = (Resolve-Path $Source).Path
    $SourceBasepath = $SourceFullpath.Split("\")[-1]
    $Total = $FileList.Count
    $Position = 0

    <#
        Loop through files checking for optional parts. Not sure if there is a faster way
    #>
    foreach ($File in $FileList) {
        $TargetFile = $Target + "\" + $SourceBasepath + "\" + $File.FullName.Replace($SourceFullpath + "\", "")

        $Status = $null
        if ($ShowFileProgress) {
            $Status = "$($Position + 1)/$Total itens"
        }

        $CurrentOperation = $null
        if ($ShowFiles) {
            $CurrentOperation = $TargetFile
        }

        try {
            #Copy-Item does not override folder itens, so they must me ignored when a targetFile folder already exists
            if ((Test-Path -LiteralPath $File.FullName -PathType Leaf) -or -Not (Test-Path -LiteralPath $TargetFile)) {
                Copy-Item -LiteralPath $File.FullName "$TargetFile" -Force -PassThru | Out-Null
            }
        } catch {
            Write-Host "Failed to copy $TargetFile" -ForegroundColor Red
            Throw $_.Exception
        }

        Write-Progress -Activity $Message -Status $Status -CurrentOperation $CurrentOperation -PercentComplete (++$Position / $Total * 100)
    }

    Write-Progress -Activity $Message -Completed

    return [PSCustomObject]@{
        StartTime   = $startTime
        EndTime     = Get-Date
        Source      = $sourceFullpath
        Target      = $Target
        Count       = $Total
    }
}

<#
.SYNOPSIS
    Remove a System service or driver

.PARAMETER Name
The name of the service or Driver

.EXAMPLE
    Remove-LocalService -Name 'ServiceName'

.LINK
    Links to further documentation.

.NOTES
    Only works for the Drivers Asusgio2 or Asusgio3
#>
function Remove-LocalService {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $Name
    )

    if (Get-Command 'Remove-Service' -errorAction SilentlyContinue) {
        Remove-Service -Name $Service
    } else {
        if (($Name -eq 'Asusgio2') -or ($Name -eq 'Asusgio3') -or ($Name -eq 'GLCKIO2')) {
            $Service = Get-WmiObject -Class Win32_SystemDriver -Filter "Name='$Name'"
        } else {
            $Service = Get-WmiObject -Class Win32_Service -Filter "Name='$Name'"
        }
        $Service.Delete() | Out-Null
    }
}

<#
.SYNOPSIS
    Get the current LocalUser SID

.OUTPUTS
    Returns the currentLocalUser SID

.EXAMPLE
    Get-UserSID
#>
function Get-UserSID {
    return (Get-LocalUser -Name $Env:USERNAME).SID.Value
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
    Param (
        [Parameter(Mandatory)]
        [String] $LiveDashUrl
    )

    #This is first just to avoid possible user confusion
    #LIVEDASH
    if ($LiveDashUrl) {
        if (-Not (Test-Path '..\Apps\LiveDash.zip')) {
            Write-Host 'Downloading LiveDash...'
            Invoke-WebRequest $LiveDashUrl -OutFile '..\Apps\LiveDash.zip'
        } else {
            Write-Warning "LiveDash already downloaded. Extracting..."
        }
        Remove-Item '..\Apps\LiveDash\*' -Recurse -ErrorAction SilentlyContinue
        Expand-Archive '..\Apps\LiveDash.zip' -DestinationPath "..\Apps\LiveDash\" -Force -ErrorAction Stop
    }

    #AISUITE
    if (-Not (Test-Path '..\Apps\AiSuite3.zip')) {
        Write-Host "Downloading AiSuite3 (installation optional)..."
        Invoke-WebRequest $AiSuite3Url -OutFile '..\Apps\AiSuite3.zip'
    } else {
        Write-Warning "AiSuite3 already downloaded (installation optional). Extracting..."
    }
    Remove-Item '..\Apps\AiSuite3\*' -Recurse -ErrorAction SilentlyContinue
    Expand-Archive '..\Apps\AiSuite3.zip' -DestinationPath "..\Apps\AiSuite3\" -Force -ErrorAction Stop

    #AuraSync
    if (-Not (Test-Path '..\Apps\AuraSync.zip')) {
        Write-Host 'Downloading AuraSync...'
        Invoke-WebRequest $AuraSyncUrl -OutFile '..\Apps\AuraSync.zip'
    } else {
        Write-Warning "AuraSync already downloaded. Extracting..."
    }
    Remove-Item '..\Apps\AuraSync\*' -Recurse -ErrorAction SilentlyContinue
    Expand-Archive '..\Apps\AuraSync.zip' -DestinationPath "..\Apps\AuraSync\" -Force -ErrorAction Stop

    #Armoury Uninstall Tool
    if (-Not (Test-Path '..\Apps\Uninstall.zip')) {
        Write-Host 'Downloading Armoury Crate Uninstall Tool...'
        Invoke-WebRequest $UninstallToolUrl -OutFile '..\Apps\Uninstall.zip'
    } else {
        Write-Warning "Armoury Crate Uninstall Tool already downloaded. Extracting..."
    }
    try {
        Remove-Item '..\Apps\Uninstall\*' -Recurse -ErrorAction SilentlyContinue
        Expand-Archive '..\Apps\Uninstall.zip' -DestinationPath "..\Apps\Uninstall\" -Force -ErrorAction Stop
    } catch {
        Resolve-Error $_.Exception 'Failed to extract uninstall tool'
    }
}

<#
    Clear and Nuke Asus Bloatware stuff
#>
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

    $AuraUninstaller = "${Env:ProgramFiles(x86)}\InstallShield Installation Information\$AuraSyncGuid"
    $LiveDashUninstaller = "${Env:ProgramFiles(x86)}\InstallShield Installation Information\$LiveDashGuid"
    $AiSuite3Path = "${Env:ProgramFiles(x86)}\Asus\AI Suite III\AISuite3.exe"
    $GlckIODriver = "${Env:ProgramData}\Package Cache\$GlckIODriverGuid\GlckIODrvSetup.exe"

    $Services = @(
        'asComSvc'
        , 'aaHMSvc'
        , 'asHmComSvc'
        , 'AsusCertService'
        , 'AsusFanControlService'
        , 'AsusUpdateCheck'
        , 'AsusROGLSLService'
        , 'LightingService'
        , 'GameSDK'
        , 'GameSDK Service'
        , 'AsSysCtrlService'
        , 'GLCKIO2' #Asus Driver
        , 'Asusgio2' #Asus Driver
        , 'Asusgio3' #Asus Driver
    )
    $Files = @(
        "${Env:ProgramFiles(x86)}\ASUS"
        , "${Env:ProgramFiles(x86)}\LightingService"
        , "${Env:ProgramFiles(x86)}\ENE"
        , "${Env:ProgramFiles(x86)}\ASUS"
        , "${Env:ProgramFiles}\ASUS"
        , "${Env:ProgramData}\ASUS"
        , "${Env:ProgramFiles(x86)}\InstallShield Installation Information"
        , "$Env:SystemRoot\System32\AsIO2.dll"
        , "$Env:SystemRoot\System32\AsIO3.dll"
        , "$Env:SystemRoot\System32\AsusDownLoadLicense.exe"
        , "$Env:SystemRoot\System32\AsusUpdateCheck.exe"
        , "$Env:SystemRoot\System32\drivers\AsIO2.sys"
        , "$Env:SystemRoot\System32\drivers\AsIO3.sys"
        , "$Env:SystemRoot\System32\drivers\GLCKIO2.sys"
        , "$Env:SystemRoot\SysWOW64\AsIO.dll"
        , "$Env:SystemRoot\SysWOW64\AsIO2.dll"
        , "$Env:SystemRoot\SysWOW64\AsIO3.dll"
        , "$Env:SystemRoot\SysWOW64\Drivers\AsIO.sys"
        , "${Env:ProgramData}\Package Cache\{5960FD0F-BB3B-49AF-B175-F77DC91E995A}v1.0.10"
        , "${Env:ProgramData}\Package Cache\{5960FD0F-BB3B-49AF-B175-F77DC91E995A}v1.0.20"
    )
    $Registries = Get-Content '..\Source\registries.txt' | Where-Object { $_.Trim() -ne '' }

    Write-Output 'Uninstall apps (please wait, this can take a while)...'
    try {

        if (Test-Path $AiSuite3Path) {
            Write-Host 'Uninstalling AiSuite 3...'
            Start-Process "${Env:ProgramData}\ASUS\AI Suite III\Setup.exe" -ArgumentList '-u -s' -Wait
            Start-Sleep 1
        }
        if (Test-Path "$LiveDashUninstaller") {
            Write-Host 'Uninstalling LiveDash...'

            #InstallShield Setup.exe is missing after silent install.
            Copy-Item '.\Setups\Setup.exe' "$LiveDashUninstaller\Setup.exe" -Force -ErrorAction Stop
            Copy-Item '..\Source\uninstall-livedash.iss' "$LiveDashUninstaller\uninstall.iss" -Force -ErrorAction Stop
            Start-Process "$LiveDashUninstaller\Setup.exe" -ArgumentList "-l0x9 -x -s -ARP -f1`"$LiveDashUninstaller\uninstall.iss`"" -Wait
            Start-Sleep 1
        }
        if (Test-Path "$AuraUninstaller") {
            Write-Host 'Uninstalling AuraSync...'

            #InstallShield Setup.exe is missing after silent install.
            Copy-Item '.\Setups\Setup.exe' "$AuraUninstaller\Setup.exe" -Force -ErrorAction Stop
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

    Write-Output 'Running Uninstall Tool (please wait, this can take a while)...'
    try {
        $UninstallSetup = (Get-ChildItem '..\Apps\Uninstall\*Armoury Crate Uninstall Tool.exe' -Recurse).FullName
        Start-Process $UninstallSetup -ArgumentList '-silent' -Wait

        #Sometimes executing again lead to better results
        Start-Process $UninstallSetup -ArgumentList '-silent' -Wait
        Start-Sleep 1
    } catch {
        Resolve-Error $_.Exception 'Uninstall tool failed'
    }

    Write-Output 'Removing services...'
    foreach ($Service in $Services) {
        Write-Information "Stopping service '$Service'"
        try {
            Stop-Service -Name "$Service" -ErrorAction Stop
        }
        catch {
            Write-Debug $_.Exception
        }

        Write-Information "Removing service '$Service'"
        try {
            Remove-LocalService -Name $Service -ErrorAction Stop
        } catch {
            Write-Debug $_.Exception
        }
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

    Write-Output 'Removing remaining files...'
    foreach ($File in $Files) {
        try {
            Write-Information "Removing '$File'"

            #Will delete folder but don't stop on first error
            Remove-FileFolder $File $True -ErrorAction Stop
        } catch {
            Write-Debug $_.Exception
        }
    }

    Write-Output 'Removing registries...'
    foreach ($Registry in $Registries) {
        try {
            $Registry = $Registry.Replace('<usersid>', $UserSID)
            $Registry = $Registry.Replace('<aurasyncguid>', $AuraSyncGuid)
            $Registry = $Registry.Replace('<livedashguid>', $LiveDashGuid)

            Write-Information "Removing '$Registry'"
            Remove-Item "Registry::$Registry" -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Debug $_.Exception
        }
    }

    Start-Process '.\Setups\AuraCleaner.exe' -Wait | Out-Null
}

<#
.SYNOPSIS
    Update and patch AuraModules. A dropdown for module selection is shown

.PARAMETER ModulesPath
    The path where the AuraSync modules are. (Mandatory)

.PARAMETER HasLiveDash
    To whether or not update modules based on older AuraSync (Optional, Defaults to $False)

.EXAMPLE
    Update-AuraModules -ModulesPath 'ModulesPath'

.EXAMPLE
    Update-AuraModules -ModulesPath 'ModulesPath' -HasLiveDash $True

.NOTES
    If HasLiveDash is $True and none of AacMBSetup.exe, AacDisplaySetup.exe AacAIOFanSetup.exe modules were selected AacMBSetup is added
#>
function Update-AuraModules {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $ModulesPath,

        [Parameter()]
        [Boolean] $HasLiveDash = $False
    )

    $Modules = Get-Content '..\Source\HalVersion.txt'
    $Selected = Show-AuraDropdown

    # Mandatory modules
    $Selected.Add('AuraServiceSetup.exe')
    if ($HasLiveDash -and -not ($Selected.Contains('AacMBSetup.exe') -or $Selected.Contains('AacDisplaySetup.exe') -or $Selected.Contains('AacAIOFanSetup.exe'))) {
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
                    Get-ChildItem "$ModulesPath\aac\*$ModuleSetup" -Recurse | Remove-Item -Force -ErrorAction Stop
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

    $options = [ordered]@{
        'AacAIOFanSetup.exe'='Asus AIO'
        ; 'AacCorsairSetup.exe'='Corsair'
        ; 'AacDisplaySetup.exe'='Display'
        ; 'AacENEDramSetup.exe-AacHal_ENE_DRAM_RGB_6K7742.exe-AacSetup.exe-AacSetup_DramHAL.exe'='RAM'
        ; 'AacExtCardSetup.exe'='Extension Card'
        ; 'AacGalaxSetup.exe'='Galax'
        ; 'AacHeadSetSetup.exe'='Headset'
        ; 'AacKbSetup.exe'='Desktop Keyboard'
        ; 'AacKingstonSetup.exe'='Kingston'
        ; 'AacMBSetup.exe'='Motherboard'
        ; 'AacMousePadSetup.exe'='Mousepad'
        ; 'AacMouseSetup.exe'='Mouse'
        ; 'AacNBDTSetup.exe-UpdateNBDTHal.exe'='Laptop Keyboard (NBDT)'
        ; 'AacOddSetup.exe'='ODD Controller'
        ; 'AacPatriotM2Setup.exe-AacPatriotSetup.exe-AacPatriotDRAMSetup.exe'='Patriot'
        ; 'AacPhisonSetup.exe'='Phison'
        ; 'AacSetup_ENE_EHD_M2_HAL-AacSetup_ENE_EHD_M2_HAL.exe'='SSD/HD'
        ; 'AacTerminalHal.exe'='Aura Terminal'
        ; 'AacVGASetup.exe'='VGA'
    }

    $Checkboxes = @()
    $Y = 20

    foreach ($Key in $options.Keys) {
        $Checkbox = New-Object System.Windows.Forms.CheckBox
        $Checkbox.Name = $Key
        $Checkbox.Text = $options[$Key]
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

    $Result = New-Object Collections.Generic.List[String]
    foreach ($Checkbox in $Checkboxes) {
        if ($Checkbox.Checked) {
            $Checkbox.Name.Split('-') | ForEach-Object { $Result.Add($_) | Out-Null }
        }
    }

    #Prevents pipe to cast ArrayList to Object
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

    Write-Host 'Set ASUS basic services through AiSuite3 quick setup...'
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