<# ================================ UTILS FUNCTIONS ================================ #>

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
    Remove a system service or driver

.PARAMETER Name
    The name of the service or Driver

.EXAMPLE
    Remove-DriverService -Name 'Driver|Service name'
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

    if ($Object) {
        Write-Information "Stopping $ObjectType '$Name'"
        Stop-Service -Name $Name -Force -NoWait
        Start-Sleep 10
        Stop-Service -Name $Name -Force

        Write-Information "Removing $ObjectType '$Name'"
        if (Get-Command 'Remove-Service' -ErrorAction SilentlyContinue) {
            Remove-Service -Name $Name
        } else {
            $Object | Remove-CimInstance
        }

        #Recommended by Microsoft
        Invoke-Expression "sc.exe delete '$Name'" | Out-Null

        #Sometimes helps
        Stop-Process -Name $Name -Force -ErrorAction SilentlyContinue
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
