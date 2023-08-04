<# ================================ FUNCTIONS ================================ #>

<#
    Handles Exception exit strategy
#>
function Resolve-Error {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [Exception] $ex,

        [String] $message
    )

    Write-Debug $ex
    Write-Host "`n$($ex.Message)" -ForegroundColor Red
    Write-Host "`n$message" -ForegroundColor Red
    Read-Host -Prompt "Press [ENTER] to exit"

    Exit
}

function Convert-UnicodeToEmoji {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $unicode
    )

    return [System.Char]::ConvertFromUtf32([System.Convert]::toInt32($unicode, 16))
}

function Import-Config {

    try {
        $settings = Get-Content -Raw '..\Source\settings.json' | ConvertFrom-Json -ErrorAction Stop
        Write-Information $settings
    } catch {
        Resolve-Error $_.Exception 'failed to load configuration file'
    }

    $Global:AsusSetupToolVersion = $settings.version
    $Global:AuraSyncUrl = $settings.AuraSyncUrl
    $Global:AiSuite3Url = $settings.AiSuite3Url
    $Global:LiveDashUrl = $settings.LiveDashUrl
    $Global:UninstallToolUrl = $settings.UninstallToolUrl
    $Global:AuraSyncGuid = $settings.AuraSyncGuid
    $Global:LiveDashGuid = $settings.LiveDashGuid
    $Global:GlckIODriverGuid = $settings.GlckIODriverGuid
    $Global:GlckIO2DriverGuid = $settings.GlckIO2DriverGuid
    $Global:UserSID = Get-UserSID
}

function Write-HeaderTitle {
    $emoji = Convert-UnicodeToEmoji '1F680'
    Write-Host "
    ___   _____ __  _______    _____      __                 ______            __
   /   | / ___// / / / ___/   / ___/___  / /___  ______     /_  __/___  ____  / /
  / /| | \__ \/ / / /\__ \    \__ \/ _ \/ __/ / / / __ \     / / / __ \/ __ \/ /
 / ___ |___/ / /_/ /___/ /   ___/ /  __/ /_/ /_/ / /_/ /    / / / /_/ / /_/ / /
/_/  |_/____/\____//____/   /____/\___/\__/\__,_/ .___/    /_/  \____/\____/_/
                                               /_/
    version: $emoji $AsusSetupToolversion $emoji
    author: CodeCrafting-io
    " -ForegroundColor Cyan
}

function Get-IsWindows11 {
    $buildVersion = $([System.Environment]::OSVersion.Version.Build)
    if ($buildVersion -ge '22000') {
        return $true
    }

    return $false
}

function Remove-FileFolder {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $path,

        [bool] $removeContainer = $false
    )

    $files = Get-ChildItem $path -Recurse
    $lastException = $null
    foreach ($file in $files) {
        try {
            Remove-Item $file.FullName -Force -Recurse -ErrorAction Stop
        } catch {
            $lastException = $_.Exception
        }
    }
    if ($removeContainer) {
        Remove-Item -Path $path -Force -Recurse
    }
    if ($lastException) {
        throw $lastException
    }
}

function Read-HostColor {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String] $message,

        [Parameter(Mandatory)]
        [String] $ForegroundColor
    )

    Write-Host $message -ForegroundColor $ForegroundColor
    Read-Host
}


<#
    Copy Item showing a progress. Returns true if successfull or throw a exception if failed
#>
function Copy-ItemWithProgress
{
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $source,

        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $target,

        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $message,

        [bool] $showFileProgress = $true,

        [bool] $showFiles = $false
    )

    $startTime = Get-Date

    if ($source.Length -lt 2) {
        Throw "source path '$source' is invalid"
    } elseif ($source[$source.Length - 1] -eq "\") {
        $source = $source.Substring(0, $source.Length - 1)
    }

    if ($target.Length -lt 2) {
        Throw "target path '$target' is invalid"
    } elseif ($target[$target.Length - 1] -eq "\") {
        $target = $target.Substring(0, $target.Length - 1)
    }

    $filelist = Get-ChildItem "$Source" -Recurse
    $sourceFullpath = (Resolve-Path $source).Path
    $sourceBasepath = $sourceFullpath.Split("\")[-1]
    $total = $filelist.Count
    $position = 0

    <#
        Loop through files checking for optional parts. Not sure if there is a faster way
    #>
    foreach ($file in $filelist) {
        #$targetFile = [Management.Automation.WildcardPattern]::Escape($target + "\" + $source + "\" + $file.FullName.Replace($sourceFullpath, ""))
        $targetFile = $target + "\" + $sourceBasepath + "\" + $file.FullName.Replace($sourceFullpath + "\", "")

        $status = $null
        if ($showFileProgress) {
            $status = "$($position + 1)/$total itens"
        }

        $currentOperation = $null
        if ($showFiles) {
            $currentOperation = $targetFile
        }

        try {
            #Copy-Item does not override folder itens, so they must me ignored when a targetFile folder already exists
            if ((Test-Path -LiteralPath $file.FullName -PathType Leaf) -or -Not (Test-Path -LiteralPath $targetFile)) {
                Copy-Item -LiteralPath $file.FullName "$targetFile" -Force -PassThru | Out-Null
            }
        } catch {
            Write-Host "Failed to copy $targetFile" -ForegroundColor Red
            Throw $_.Exception
        }

        Write-Progress -Activity $message -Status $status -CurrentOperation $currentOperation -PercentComplete (++$position / $total * 100)
    }

    Write-Progress -Activity $message -Completed

    return [PSCustomObject]@{
        StartTime   = $startTime
        EndTime     = Get-Date
        Source      = $sourceFullpath
        Target      = $target
        Count       = $total
    }
}

function Remove-LocalService {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $name
    )

    if (Get-Command 'Remove-Service' -errorAction SilentlyContinue) {
        Remove-Service -Name $service
    } else {
        if (($name -eq 'Asusgio2') -or ($name -eq 'Asusgio3')) {
            $service = Get-WmiObject -Class Win32_SystemDriver -Filter "Name='$name'"
        } else {
            $service = Get-WmiObject -Class Win32_Service -Filter "Name='$name'"
        }
        $service.delete() | Out-Null
    }
}

<#
    Get the username SID
#>
function Get-UserSID {
    return (Get-LocalUser -Name $env:USERNAME).sid.value
}

function Get-AsusSetup {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String] $liveDashUrl
    )

    #This is first just to avoid possible user confusion
    #LIVEDASH
    if ($liveDashUrl) {
        if (-Not (Test-Path '..\Apps\LiveDash.zip')) {
            Write-Host 'downloading LiveDash...'
            Invoke-WebRequest $liveDashUrl -OutFile '..\Apps\LiveDash.zip'
        } else {
            Write-Warning "LiveDash already downloaded. Extracting..."
        }
        Remove-Item '..\Apps\LiveDash\*' -Recurse -ErrorAction SilentlyContinue
        Expand-Archive '..\Apps\LiveDash.zip' -DestinationPath "..\Apps\LiveDash\" -Force -ErrorAction Stop
    }

    #AISUITE
    if (-Not (Test-Path '..\Apps\AiSuite3.zip')) {
        Write-Host "downloading AiSuite3 (installation optional)..."
        Invoke-WebRequest $AiSuite3Url -OutFile '..\Apps\AiSuite3.zip'
    } else {
        Write-Warning "AiSuite3 already downloaded (installation optional). Extracting..."
    }
    Remove-Item '..\Apps\AiSuite3\*' -Recurse -ErrorAction SilentlyContinue
    Expand-Archive '..\Apps\AiSuite3.zip' -DestinationPath "..\Apps\AiSuite3\" -Force -ErrorAction Stop

    #AuraSync
    if (-Not (Test-Path '..\Apps\AuraSync.zip')) {
        Write-Host 'downloading AuraSync...'
        Invoke-WebRequest $AuraSyncUrl -OutFile '..\Apps\AuraSync.zip'
    } else {
        Write-Warning "AuraSync already downloaded. Extracting..."
    }
    Remove-Item '..\Apps\AuraSync\*' -Recurse -ErrorAction SilentlyContinue
    Expand-Archive '..\Apps\AuraSync.zip' -DestinationPath "..\Apps\AuraSync\" -Force -ErrorAction Stop

    #Armoury Uninstall Tool
    if (-Not (Test-Path '..\Apps\Uninstall.zip')) {
        Write-Host 'downloading Armoury Crate Uninstall Tool...'
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
function Clear-AsusBloat {

    [CmdletBinding()]
    PARAM()

    $auraUninstaller = "${Env:ProgramFiles(x86)}\InstallShield Installation Information\$AuraSyncGuid"
    $liveDashUninstaller = "${Env:ProgramFiles(x86)}\InstallShield Installation Information\$LiveDashGuid"
    $aisuite3Path = "${Env:ProgramFiles(x86)}\Asus\AI Suite III\AISuite3.exe"
    $glckioDriver = "${Env:ProgramData}\Package Cache\$GlckIODriverGuid\GlckIODrvSetup.exe"

    $services = @(
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
    $files = @(
        "${Env:ProgramFiles(x86)}\ASUS"
        , "${Env:ProgramFiles(x86)}\LightingService"
        , "${Env:ProgramFiles(x86)}\ENE"
        , "${Env:ProgramFiles(x86)}\ASUS"
        , "${Env:ProgramFiles}\ASUS"
        , "${Env:ProgramData}\ASUS"
        , "${Env:ProgramFiles(x86)}\InstallShield Installation Information"
        , "$env:SystemRoot\System32\AsIO2.dll"
        , "$env:SystemRoot\System32\AsIO3.dll"
        , "$env:SystemRoot\System32\AsusDownLoadLicense.exe"
        , "$env:SystemRoot\System32\AsusUpdateCheck.exe"
        , "$env:SystemRoot\System32\drivers\AsIO2.sys"
        , "$env:SystemRoot\System32\drivers\AsIO3.sys"
        , "$env:SystemRoot\System32\drivers\GLCKIO2.sys"
        , "$env:SystemRoot\SysWOW64\AsIO.dll"
        , "$env:SystemRoot\SysWOW64\AsIO2.dll"
        , "$env:SystemRoot\SysWOW64\AsIO3.dll"
        , "$env:SystemRoot\SysWOW64\Drivers\AsIO.sys"
        , "${Env:ProgramData}\Package Cache\{5960FD0F-BB3B-49AF-B175-F77DC91E995A}v1.0.10"
        , "${Env:ProgramData}\Package Cache\{5960FD0F-BB3B-49AF-B175-F77DC91E995A}v1.0.20"
    )
    $registries = Get-Content '..\Source\registries.txt' | Where-Object { $_.Trim() -ne '' }

    Write-Output 'uninstall apps (please wait, this can take a while)...'
    try {

        if (Test-Path $aisuite3Path) {
            Write-Host 'uninstalling AiSuite 3...'
            Start-Process "${Env:ProgramData}\ASUS\AI Suite III\Setup.exe" -ArgumentList '-u -s' -Wait
            #Start-Process '..\Apps\AiSuite3\AsusSetup.exe' -ArgumentList '/x /s /norestart' -Wait
            Start-Sleep 1
        }
        if (Test-Path "$liveDashUninstaller") {
            Write-Host 'uninstalling LiveDash...'

            #InstallShield Setup.exe is missing after silent install.
            Copy-Item '.\Setups\Setup.exe' "$liveDashUninstaller\Setup.exe" -Force -ErrorAction Stop
            Copy-Item '..\Source\uninstall-livedash.iss' "$liveDashUninstaller\uninstall.iss" -Force -ErrorAction Stop
            Start-Process "$liveDashUninstaller\Setup.exe" -ArgumentList "-l0x9 -x -s -ARP -f1`"$liveDashUninstaller\uninstall.iss`"" -Wait
            Start-Sleep 1
        }
        if (Test-Path "$auraUninstaller") {
            Write-Host 'uninstalling AuraSync...'

            #InstallShield Setup.exe is missing after silent install.
            Copy-Item '.\Setups\Setup.exe' "$auraUninstaller\Setup.exe" -Force -ErrorAction Stop
            Copy-Item '..\Source\uninstall-aurasync.iss' "$auraUninstaller\uninstall.iss" -Force -ErrorAction Stop
            Start-Process "$auraUninstaller\Setup.exe" -ArgumentList "-l0x9 -x -s -ARP -f1`"$auraUninstaller\uninstall.iss`"" -Wait
            Start-Sleep 1
        }
        if (Test-Path $glckioDriver) {
            Write-Host 'uninstalling glckio2...'

            Start-Process $glckioDriver -ArgumentList '/uninstall /quiet' -Wait
            Start-Process "$env:SystemRoot\System32\msiexec.exe" -ArgumentList "/x $GlckIOD2riverGuid /quiet" -Wait
            Start-Sleep 1
        }
    } catch {
        #In case of error manual uninstallation is required here
        Resolve-Error $_.Exception 'Uninstall apps failed. Manual uninstallation may be required for Aura|LiveDash|AiSuite3'
    }

    Write-Output 'running uninstall tool (please wait, this can take a while)...'
    try {
        $uninstallSetup = (Get-ChildItem '..\Apps\Uninstall\*Armoury Crate Uninstall Tool.exe' -Recurse).FullName
        Start-Process $uninstallSetup -ArgumentList '-silent' -Wait

        #Sometimes executing again lead to better results
        Start-Process $uninstallSetup -ArgumentList '-silent' -Wait
        Start-Sleep 2
    } catch {
        Resolve-Error $_.Exception 'Uninstall tool failed'
    }

    Write-Output 'removing services...'
    foreach ($service in $services) {
        # Hide errors
        try {
            Write-Information "Stopping service '$service'"
            Stop-Service -Name "$service" -ErrorAction Stop
        }
        catch {
            Write-Debug $_.Exception
        }

        Write-Information "Removing service $service"
        try {
            Remove-LocalService -Name $service -ErrorAction Stop
        } catch {
            Write-Debug $_.Exception
        }
    }

    Write-Output 'removing tasks...'
    try {
        Write-Information 'Unregister tasks'
        Unregister-ScheduledTask -TaskPath '\Asus\*' -Confirm:$false -ErrorAction Stop

        $sch = New-Object -ComObject Schedule.Service
        $sch.connect()
        $rootFolder = $sch.GetFolder("\")
        $rootFolder.DeleteFolder("Asus", $null)

        Write-Information 'Removing Task folder'
        Remove-Item "$env:SystemRoot\System32\Asus" -ErrorAction Stop
    } catch {
        Write-Debug $_.Exception
    }

    Write-Output 'removing remaining files...'
    foreach ($file in $files) {
        try {
            Write-Information "Removing '$file'"

            #Will delete folder but don't stop on first error
            Remove-FileFolder $file $true -ErrorAction Stop
        } catch {
            Write-Debug $_.Exception
        }
    }

    Write-Output 'removing registries...'
    foreach ($registry in $registries) {
        try {
            $registry = $registry.Replace('<usersid>', $UserSID)
            $registry = $registry.Replace('<aurasyncguid>', $AuraSyncGuid)
            $registry = $registry.Replace('<livedashguid>', $LiveDashGuid)

            Write-Information "Removing '$registry'"
            Remove-Item "Registry::$registry" -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Debug $_.Exception
        }
    }

    Start-Process '.\Setups\AuraCleaner.exe' -Wait | Out-Null
}

function Update-AuraModules {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $modulesPath,

        [Parameter()]
        [Boolean] $hasLiveDash
    )

    $modules = Get-Content '..\Source\HalVersion.txt'

    <#
    if (-Not (Test-Path "$modulesPath\HalVersion.txt")) {
        $modules = Get-Content '..\Source\HalVersion.txt'
    } else {
        $modules = Get-Content "$modulesPath\HalVersion.txt"
    }
    #>
    $selected = Show-AuraDropdown

    # Mandatory modules
    $selected.Add('AuraServiceSetup.exe')
    if ($hasLiveDash -and -not ($selected.Contains('AacMBSetup.exe') -or $selected.Contains('AacDisplaySetup.exe') -or $selected.Contains('AacAIOFanSetup.exe'))) {
        $selected.Add('AacMBSetup.exe')
    }
    $newModules = @()
    foreach ($module in $modules) {
        #Skip blank lines
        if ($module.Length -gt 0) {
            $moduleSetup = ($module.Substring(10, $module.IndexOf("]'s") - 10))
            if ($selected.Contains($moduleSetup)) {
                Write-Information ($moduleSetup + ' to keep')
                $newModules += $module
            } else {
                try {
                    #Newer Aura versions have changed setup folder structure, this search for files
                    Get-ChildItem "$modulesPath\aac\*$moduleSetup" -Recurse | Remove-Item -Force -ErrorAction Stop
                    Write-Information ($moduleSetup + ' to remove')
                } catch {
                    Write-Debug $_.Exception
                }
            }
        }
    }
    Out-File ($modulesPath + '\HalVersion.txt') -InputObject $newModules
}

function Show-AuraDropdown {
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

    $Form = New-Object System.Windows.Forms.Form
    $Form.Size = New-Object System.Drawing.Size(350,250)
    $Form.text ="Choose AuraSync modules"
    $labelFont = New-Object System.Drawing.Font('Segoe UI', 10)

    ############################################## Start group boxes

    $groupBox = New-Object System.Windows.Forms.GroupBox
    $groupBox.Location = New-Object System.Drawing.Size(($Form.Size.Width - 50), 20)
    $groupBox.Left = 10
    $groupBox.Top = 5
    $groupBox.text = "AuraSync modules"
    $groupBox.Font = $labelFont
    $Form.Controls.Add($groupBox)

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
    $y = 20

    foreach ($key in $options.Keys) {
        $Checkbox = New-Object System.Windows.Forms.CheckBox
        $Checkbox.Name = $key
        $Checkbox.Text = $options[$key]
        $Checkbox.Location = New-Object System.Drawing.Size(10, $y)
        $Checkbox.Size = New-Object System.Drawing.Size(($Form.Size.Width - 70), 20)
        $Checkbox.Font = $labelFont
        $groupBox.Controls.Add($Checkbox)
        $Checkboxes += $Checkbox
        $y += 30
    }

    $groupBox.size = New-Object System.Drawing.Size(($Form.Size.Width - 50), ($y + 50))
    $closeButton = New-Object System.Windows.Forms.Button
    $closeButton.Location = New-Object System.Drawing.Size(10, $y)
    $closeButton.Size = New-Object System.Drawing.Size(($Form.Size.Width - 70), 35)
    $closeButton.Text = 'CONFIRM'
    $closeButton.BackColor = '#145A99'
    $closeButton.ForeColor = '#FFFFFF'
    $closeButton.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
    $closeButton.add_click({ $Form.Close() })
    $groupBox.Controls.Add($closeButton)

    $Form.size = New-Object System.Drawing.Size(350, ($y + 120))
    $form.ShowDialog() | Out-Null

    $result = New-Object Collections.Generic.List[String]
    foreach ($Checkbox in $Checkboxes) {
        if ($Checkbox.Checked) {
            $Checkbox.Name.Split('-') | ForEach-Object { $result.Add($_) | Out-Null }
        }
    }

    #Prevents pipe to cast ArrayList to Object
    return ,$result
}

function Set-AsusService {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String][ValidateNotNullOrEmpty()] $aisuitePath,

        [Parameter()]
        [double] $wait = 10
    )

    Write-Host 'set asus basic services through AiSuite3 quick setup...'
    $start = Get-Date
    $setup = Start-Process $aisuitePath -PassThru

    while (($setup.MainWindowTitle -ne 'AI Suite 3 Setup') -and (((Get-Date) - $start).Seconds -le $wait)) {
        $setup = Get-Process -Id $setup.Id
    }

    $setup.Kill()
    if ($setup.MainWindowTitle -ne 'AI Suite 3 Setup') {
        Throw 'failed to set Asus service'
    }
}

<#
    Despite AsusCertService can execute without other services, something is missing here
function Set-AsusService2 {

    Write-Host 'setting ASIO drivers...'
    Copy-Item '..\Source\ASIO2\AsIO2_64.dll' "$env:SystemRoot\system32\AsIO2.dll" -Force
    Copy-Item '..\Source\ASIO2\AsIO2_64.sys' "$env:SystemRoot\system32\drivers\AsIO2.sys" -Force
    Copy-Item '..\Source\ASIO3\AsIO3_64.dll' "$env:SystemRoot\system32\AsIO3.dll" -Force
    Copy-Item '..\Source\ASIO3\AsIO3_64.sys' "$env:SystemRoot\system32\drivers\AsIO3.sys" -Force
    sc.exe create 'Asusgio2' binPath="$env:SystemRoot\system32\drivers\AsIO2.sys" type=kernel | Out-Null
    sc.exe create 'Asusgio3' binPath="$env:SystemRoot\system32\drivers\AsIO3.sys" type=kernel | Out-Null
    Start-Service 'Asusgio2'
    Start-Service 'Asusgio3'

    Write-Host 'setting Asus Cert Service'
    New-Item -ItemType Directory -Path "${Env:ProgramFiles(x86)}\Asus\AsusCertService" -Force | Out-Null
    Copy-Item '..\Source\ASIO3\AsusCertService.exe' "${Env:ProgramFiles(x86)}\Asus\AsusCertService\AsusCertService.exe" -Force

    # Stop any mmc that prevents recreating the service
    try {
        Stop-Process -Name 'mmc' -ErrorAction Stop | Out-Null
    } catch {
        Write-Debug $_.Exception
    }
    New-Service -Name 'AsusCertService' -DisplayName 'AsusCertService' -BinaryPathName "${Env:ProgramFiles(x86)}\Asus\AsusCertService\AsusCertService.exe" -StartupType  'auto' -DependsOn 'RpcSs' |
    New-Service -Name 'asHmComSvc' -DisplayName 'ASUS HM Com Service' -BinaryPathName "${Env:ProgramFiles(x86)}\ASUS\AAHM\1.00.31\aaHMSvc.exe" -StartupType 'auto' -DependsOn 'RpcSs' | Out-Null
}
#>
