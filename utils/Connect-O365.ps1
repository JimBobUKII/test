[CmdletBinding()]
Param(
  [Hashtable]$Settings
)

Function main {

  Import-Module -Name (Resolve-Path -Path "$PSScriptRoot/../modules/Smiths.psm1") -Force
  Import-SmithsConfig -Overrides $Settings

  Import-SmithsModule -Name "SmithsLogging.psm1"
  Start-SmithsLog -Component "Connect to Office 365 PowerShell" -LogRun:$false -ReadOnly:$ReadOnly

  Import-SmithsModule -Name "SmithsO365.psm1"

  Connect-SmithsO365

  Stop-SmithsLog
}


main
