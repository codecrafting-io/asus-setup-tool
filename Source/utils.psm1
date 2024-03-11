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
        [System.Management.Automation.ErrorRecord] $ErrorContext,

        [String] $Message,
        [bool] $Stop = $True
    )

    try {
        Write-Log -Message $ErrorContext -Level 'ERROR' -OutputHost $False -ErrorAction Stop
    } catch {
        Write-Error "`nFailed to log error: $($_.Exception.Message)"
    }
    $ErrorActionPreference = 'Stop';

    Write-Host "`n$($ErrorContext.Exception.Message)" -ForegroundColor Red
    Write-Host "`n$Message" -ForegroundColor Red

    if ($Stop) {
        Read-Host -Prompt 'Press [ENTER] to exit'
        Exit
    }
}

<#
.SYNOPSIS
    Write messages to the host and log to a file

.PARAMETER Message
    The message object. If object is an ErrorRecord it will log the exception details

.PARAMETER Level
    The standard log levels (INFO, WARN, ERROR, DEBUG, VERBOSE) + HOST to write without a log level.
    Messages written in the host also use the log level, like: INFO = Write-Information

.PARAMETER Folder
    The folder locating the log files. Defaults to '.\Log'

.PARAMETER FileRotation
    The number of log files to keep order by last LastWriteTime. Value must be between 1 and 100

.PARAMETER OutputHost
    To wether or not to output messages to the host

.PARAMETER HostColor
    To wether or not to use ForegroundColor when using 'HOST' log level

.EXAMPLE
    Write-Log 'Some error' -Level 'ERROR'
#>
function Write-Log {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True)]
        [System.Object] $Message,

        [String] $Level = 'HOST',
        [string][ValidateNotNullOrEmpty()] $Folder = '.\Log',
        [int][ValidateRange(1, 100)] $FileRotation = 2,
        [bool] $OutputHost = $True,
        [string] $HostColor,
        [switch] $CloseWriter = $False
    )

    $Level = $Level.ToUpper()
    if ($OutputHost) {
        switch ($Level) {
            'INFO' {
                Write-Information $Message
            }
            'WARN' {
                Write-Warning $Message
            }
            'ERROR' {
                Write-Error $Message
            }
            'DEBUG' {
                Write-Debug $Message
            }
            'VERBOSE' {
                Write-Verbose $Message
            }
            default {
                $Level = 'HOST'
                if ($HostColor) {
                    Write-Host $Message -ForegroundColor $HostColor
                } else {
                    Write-Host $Message
                }
            }
        }
    }

    if (-Not (Test-Path $Folder -PathType Container)) {
        New-Item -Path $Folder -ItemType Directory | Out-Null
    }

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    if (-Not $Global:_LogFile) {
        $File = "$Folder\$((Get-Date).toString("yyyy-MM-dd")).log"
        try {
            $Global:_LogFile = [System.IO.StreamWriter]::new($File, $True, [System.Text.Encoding]::UTF8)
            $_LogFile.AutoFlush = $True
        } catch {
            Write-Error 'Failed to initialize Log'
            Write-Debug $_.Exception
            Exit
        }
    }

    if ($Level -eq 'HOST') {
        $Level = ''
    } else {
        $Level = "[$Level]"
    }

    $MessageType = $Message.GetType().FullName
    if ($MessageType -eq 'System.Management.Automation.ErrorRecord') {
        $Line = "$Stamp $($Level):"
        $ExceptionLocation = "$($Message.InvocationInfo.ScriptName):$($Message.InvocationInfo.ScriptLineNumber)"
        $Line += " caught exception '$($Message.Exception.GetType())' at '$ExceptionLocation'`n"
        $Line += $Message
    } else {
        $Line = "$Stamp $($Level): $Message"
    }

    # Using a StreamWriter is more reliable for recurring writes to a file
    $_LogFile.WriteLine($Line)

    #Get only files of the first level order by LastWriteTime
    $Files = Get-ChildItem $Folder -File -Depth 0 | Sort-Object LastWriteTime,Name

    #Limit the deletion to delete the first files until the last $FileRotation files. If negative the for will be skipped
    $Count = $Files.Count - $FileRotation
    for ($i = 0; $i -lt $Count; $i++) {
        Write-Debug "File Rotation, exclude: $($Files[$i])"
        $Files[$i] | Remove-Item -Force
    }

    if ($CloseWriter) {
        Write-Debug 'Closing writer'
        $_LogFile.Close()
        $_LogFile = $Null
    }
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
        #Sort descending to remove files bottom up, avoiding file not found errors
        $Files = Get-ChildItem -LiteralPath $Path -Recurse -Force | Sort-Object FullName -Descending
        $LastException = $Null
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
        Write-Log "Stopping $ObjectType '$Name'" -Level 'INFO'
        Stop-Service -Name $Name -Force -NoWait
        Start-Sleep 7
        Stop-Service -Name $Name -Force

        Write-Log "Removing $ObjectType '$Name'" -Level 'INFO'
        if (Get-Command 'Remove-Service' -ErrorAction SilentlyContinue) {
            Remove-Service -Name $Name
        } else {
            $Object | Remove-CimInstance
        }

        #Recommended by Microsoft
        sc.exe delete "$Name" | Out-Null
        #Invoke-Expression "sc.exe delete '$Name'" | Out-Null

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
