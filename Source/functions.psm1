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
    Read-Host -Prompt 'Press [ENTER] to exit'

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
    Expand environment and execution context variables inside a string

.PARAMETER Value
    The value string to be expanded

.EXAMPLE
   Get-ExpandedStringVariables '%LOCALAPPDATA%\\$ContextVar'
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
    Get Json from a file

.PARAMETER JsonFile
    The Json file path

.EXAMPLE
   Get-Json 'myjson.json'

.NOTES
    This will use UTF-8 as default and remove comments
#>
function Get-Json {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [String][ValidateNotNullOrEmpty()] $JsonFile
    )

    return (Get-Content -Raw $JsonFile) -replace '\/\*[\s\S]*?\*\/|([^:]|^)\/\/[^\n\r]*' | ConvertFrom-Json
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

    $LockSettings.IntegrityList | Add-Member -Type NoteProperty -Name "..\\Source\\settings.json" -Value "2B14F4C632B02BBFB250F88176D1E821E8B8F75BDF0156FB45F76819668FBD97"
    $LockSettings.IntegrityList | Add-Member -Type NoteProperty -Name "..\\Source\\lock.jsonc" -Value "3A5C0AB9947ED879041D829F70387CD7A3197E40DCD0F02421E5DFF084B64E2B"

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

    if (Test-Path $Path -PathType Leaf) {
        Remove-Item -Path $Path -Force -Recurse
    } else {
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
}

<#
.SYNOPSIS
Start a sleep command with countdown

.PARAMETER Message
The message to be printed (mandatory)

.PARAMETER Seconds
The amout of time to sleep (mandatory)

.EXAMPLE
    Start-SleepCountdown -Message 'Message' -Seconds 10

.EXAMPLE
    Start-SleepCountdown -Message 'Message' -Seconds 10 -NoNewLine
#>
function Start-SleepCountdown {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String] $Message,

        [Parameter(Mandatory)]
        [int] $Seconds,

        [Parameter()]
        [switch] $NoNewLine = $False
    )

    $Digits = "$Seconds".Length
    for ($Timer = $Seconds; $Timer -ge 0; $Timer--) {
        Write-Host "`r$Message $("$Timer".PadLeft($Digits, '0'))`s" -NoNewLine -ForegroundColor Yellow
        Start-Sleep 1
    }
    if (-Not $NoNewLine) {
        Write-Host ' '
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

    Write-Host $Message -ForegroundColor $ForegroundColor -NoNewline
    Read-Host
}

<#
.SYNOPSIS
    Copy Item showing a progress. Returns true if successfull or throw an exception if failed

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
    Remove a system service or driver

.PARAMETER Name
    The name of the service or Driver

.EXAMPLE
    Remove-DriverService -Name 'Driver|Service name'

.LINK
    Links to further documentation.
#>
function Remove-DriverService {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $Name
    )

    $Object = Get-CimInstance -Class Win32_SystemDriver -Filter "Name='$Name'"
    $ObjectType = 'service'
    if ($Object) {
        $ObjectType = 'driver'
    }
    if ($ObjectType -eq 'service') {
        $Object = Get-CimInstance -Class Win32_Service -Filter "Name='$Name'"
    }

    #First stop
    Write-Information "Stopping $ObjectType '$Name'"
    Stop-Service -Name $Name -Force -NoWait
    Start-Sleep 5
    Stop-Service -Name $Name -Force

    Write-Information "Removing $ObjectType '$Name'"
    if (Get-Command 'Remove-Service' -ErrorAction SilentlyContinue) {
        Remove-Service -Name $Name
    } else {
        $Object | Remove-CimInstance
    }

    #Recommended by Microsoft
    Invoke-Expression "sc.exe delete '$Name'" | Out-Null
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
        [String][AllowEmptyString()] $LiveDashUrl
    )

    $SetupSettings | Add-Member -Type NoteProperty -Name 'AuraSyncUrl' -Value $SetupSettings.AuraSyncUrlNew
    $SetupSettings | Add-Member -Type NoteProperty -Name 'AuraSyncHash' -Value $SetupSettings.AuraSyncHashNew
    $SetupSettings | Add-Member -Type NoteProperty -Name 'HasLiveDash' -Value $False
    $SetupSettings | Add-Member -Type NoteProperty -Name 'IsOldAura' -Value $False

    Write-Host 'Choose the AuraSync version:'
    Write-Host "  1 - NEW: Version 1.07.84_v2 for the latest product support, but it is more bloated" -ForegroundColor Yellow
    Write-Host '  2 - OLD: Version 1.07.66 is less bloated, but may not have support for products after 2020' -ForegroundColor Yellow
    if ((Read-Host '[1] NEW [2] OLD') -eq '2') {
        $SetupSettings.IsOldAura = $True
        $SetupSettings.AuraSyncUrl = $SetupSettings.AuraSyncUrlOld
    }

    #This is first just to avoid possible user confusion
    #LIVEDASH
    if ($LiveDashUrl) {
        $SetupSettings.HasLiveDash = $True

        if (-Not (Test-Path '..\Apps\LiveDash.zip')) {
            $LiveDashVersion = $SetupSettings.LiveDashUrl.Replace("$($SetupSettings.AsusBaseUrl)/LiveDash_", '').Replace('.zip', '')
            Write-Host "Downloading LiveDash version $LiveDashVersion..."
            Invoke-WebRequest $LiveDashUrl -OutFile '..\Apps\LiveDash.zip'
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
            Copy-Item '.\Setups\Setup.exe' "$LiveDashUninstaller\Setup.exe" -Force -ErrorAction Stop
            Copy-Item '..\Source\uninstall-livedash.iss' "$LiveDashUninstaller\uninstall.iss" -Force -ErrorAction Stop
            Start-Process "$LiveDashUninstaller\Setup.exe" -ArgumentList "-l0x9 -x -s -ARP -f1`"$LiveDashUninstaller\uninstall.iss`"" -Wait
            Start-Sleep 1
        }
        if (Test-Path $AuraUninstaller) {
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

    Write-Output 'Removing remaining files...'
    foreach ($File in $LockSettings.Files) {
        $File = Get-ExpandedStringVariables $File
        try {
            Write-Information "Removing '$File'"

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
        try {
            $Registry = $Registry.Replace('<usersid>', $UserSID)
            $Registry = $Registry.Replace('<aurasyncguid>', $SetupSettings.AuraSyncGuid)
            $Registry = $Registry.Replace('<livedashguid>', $SetupSettings.LiveDashGuid)

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
    $Selected = Show-AuraDropdown

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


    #Bring some sense to this madness
    Write-Host 'Updating services dependencies...'
    try {
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
    } catch {
        Resolve-Error $_.Exception
    }

    if (Test-Path '..\Patches\Profiles\LastProfile.xml') {
        Write-Host 'Setting profiles for LightingService (wait, this will take an while)...'

        #Asus LightingService is too sensitive and some times don't load profiles properly
        try {
            Remove-Item "${Env:ProgramFiles(x86)}\LightingService\LastProfile.xml" -Force -ErrorAction Stop
            Start-Service -Name 'LightingService' -ErrorAction Stop
            Start-SleepCountdown -Message 'Reset LightingService profiles in:' -Seconds 90
            Stop-Service -Name 'LightingService' -Force -ErrorAction Stop
        } catch {
            Resolve-Error $_.Exception
        }

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
