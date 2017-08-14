<#
.SYNOPSIS
    Automatically assigns and removes O365 licenses based on Azure AD group membership.
.DESCRIPTION
    Based on a list of groups and licenses in the accompanying XML configuration file, user licenses are assigned or removed as needed. Also handles changes in license type.

    Does not remove licenses when users are disabled, in order to allow conversion to shared mailbox or inactive mailbox with legal hold.
.NOTES
    Author: David Gee, based on a script by Johan Dahlbom (see 365lab.net)

    Version History:
    Version   Date        Author                Changes
    1.0       08/29/2016  David Gee             Initial release
.PARAMETER Credential
  Specifies a credential to use when connecting to Office 365. If omitted, the user receives an interactive prompt for the credential.
#>

Add-Type -TypeDefinition @"
  public enum SmithsLogLevel
  {
     DEBUG,
     INFO,
     WARN,
     ERROR,
     FATAL
  }
"@

$logging = @{
  File = Get-SmithsConfigAllSettings -Component "File Logging"
  Console = Get-SmithsConfigAllSettings -Component "Console Logging"
}

$ConsoleLogArguments = @{
  DEBUG = @{}
  INFO = @{"-ForegroundColor"="Green"}
  WARN = @{"-ForegroundColor"="Yellow"}
  ERROR = @{"-ForegroundColor"="Red"}
  FATAL = @{"-ForegroundColor"="Red"}
}

Function Get-SmithsLoggingLevel {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("File","Console")]
    $LogType
  )
  If($script:component -in $logging.$LogType.Keys){
    $logging.$LogType[$script:component]
  }
  Else {
    "DEBUG"
  }
}

Function Get-SmithsScriptName {

  [CmdletBinding()]
  Param()

  Split-Path -Path (Get-PSCallStack | Where { $_.ScriptName -ne $null } | Select -Last 1 -ExpandProperty ScriptName) -Leaf

}

#$datestamp = (Get-Date).ToString("yyyy-MM-dd")
$datestamp = (Get-Date).ToString("yyyy-MM-dd-HH-mm")
$logdir = (Get-SmithsScriptName) -replace ".ps1$",""
$logpath = "$smithsroot\logs\$logdir\$datestamp.log"
$lastrunpath = "$smithsroot\logs\$logdir\last-run.txt"
If(-not (Test-Path $logpath)){
  $logfile = New-Item -Type File -Path $logpath -Force
}
If(-not (Test-Path $lastrunpath)){
  $lastrunfile = New-Item -Type File -Path $lastrunpath -Force
}


Function Write-SmithsLog {

  [CmdletBinding()]

  Param(
    [Parameter(Mandatory=$True)]
    [ValidateSet("FATAL", "ERROR", "WARN", "INFO", "DEBUG")]
    [String]$Level = "INFO",
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [String]$Activity,
    [String]$Identity,
    [Parameter(Mandatory=$True)]
    [string]$Message
  )
  # Get console and file thresholds for logging

  $fileLevel = Get-SmithsLoggingLevel -LogType "File"
  $consoleLevel = Get-SmithsLoggingLevel -LogType "Console"

  # Determine whether to log for each

  $LogToFile = ([Convert]::ToInt16([SmithsLogLevel]::$Level) -ge [Convert]::ToInt16([SmithsLogLevel]::$fileLevel))
  $LogToConsole = ([Convert]::ToInt16([SmithsLogLevel]::$Level) -ge [Convert]::ToInt16([SmithsLogLevel]::$consoleLevel))

  # Format message

  $timestamp = Get-Date -Format o
  If($Identity -ne $null -and $Identity -ne ""){
    $message = "${Identity}: $message"
  }
  $logMessage = "[$timestamp] [$Level] [$($script:component.ToUpper())] [$($Activity.ToUpper())] $message"

  # Log

  If($LogToFile){
    Add-Content -Path $logpath -Value $logMessage -Encoding UTF8
  }
  If($LogToConsole){
    $writehostargs = $ConsoleLogArguments.$Level
    Write-Host $logMessage -InformationAction Continue @writehostargs
  }
}

Function Write-SmithsProgress {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Activity,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Status,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [int]$Item,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [int]$Count
  )

  $percent = (100.0*$Item / $Count)
  $percentText = $percent.ToString("0.0")

  Write-Progress -Activity "$Activity ($percentText% complete)" -Status $Status -PercentComplete $percent

}

Function Start-SmithsLog {

  [CmdletBinding()]
  Param(
    [switch]$LogRun,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Component,
    [switch]$ReadOnly
  )
  $script:Component = $Component
  If($ReadOnly){
    $script:Component += " Simulation"
  }
  Write-SmithsLog -Level INFO -Activity "Execute" -Message "Script started"
  $lastrun = $null
  If($LogRun){
    Try {
      $lastrun = Get-Content $lastrunpath
      Write-SmithsLog -Level DEBUG -Activity "Execute" -Message "Fetched script last run timestamp: $lastrun"
    }
    Catch {}
    $lastrun
    $lastrunstamp = Get-Date -Format o
    Write-SmithsLog -Level DEBUG -Activity "Execute" -Message "Updated script last run timestamp: $lastrunstamp"
    Set-Content -Path $lastrunpath -Value $lastrunstamp -Encoding UTF8
  }
}

Function Stop-SmithsLog {

  [CmdletBinding()]
  Param()

  Write-SmithsLog -Level INFO -Activity "Execute" -Message "Script finished"
}

Function ConvertFrom-SmithsLogLine {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $Line
  )

  Begin {
  }

  Process {
    If($Line -match "^\[(.*)\] \[(.*)\] \[(.*)\] \[(.*)\] (.*)$"){
      [PSCustomObject]@{
        Timestamp = (($matches.1).Substring(0, 19) -replace "T", " ")
        Severity = $matches.2
        Component = $matches.3
        Activity = $matches.4
        Message = $matches.5
      }
    }
  }

  End {
  }
}

Function Get-SmithsLogEntries {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [DateTime]$Cutoff,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Pattern
  )

  Get-ChildItem -Path "$smithsroot/logs" -Filter "*.log" -Recurse | Where { $_.LastWriteTime -gt $Cutoff } | Select-String -Pattern $Pattern | Select -ExpandProperty Line | ConvertFrom-SmithsLogLine | Group-Object -Property Severity,Component,Activity,Message |% {
    [PSCustomObject]@{
      LastOccurrence = $_.Group | Sort -Descending Timestamp | Select -First 1 -ExpandProperty Timestamp
      Occurrences = $_.Count
      Severity = $_.Values[0]
      Component = $_.Values[1]
      Activity = $_.Values[2]
      Message = $_.Values[3]
    }
  } | Sort -Descending LastOccurrence

}
