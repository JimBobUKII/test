[CmdletBinding()]
Param(
  [Hashtable]$Settings
)

Function main {

  Import-Module -Name (Resolve-Path -Path "$PSScriptRoot/../modules/Smiths.psm1") -Force
  Import-SmithsConfig -Overrides $Settings

  Import-SmithsModule -Name "SmithsLogging.psm1"
  Start-SmithsLog -Component "Connect to Security and Compliance PowerShell" -LogRun:$false -ReadOnly:$ReadOnly

  Import-SmithsModule -Name "SmithsSecurityCompliance.psm1"

  Connect-SmithsSecurityCompliance

  Stop-SmithsLog
}


main


