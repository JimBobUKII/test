[CmdletBinding()]
Param(
  [Hashtable]$Settings
)

Function main {

  Import-Module -Name (Resolve-Path -Path "$PSScriptRoot/../modules/Smiths.psm1") -Force
  Import-SmithsConfig -Overrides $Settings

  Import-SmithsModule -Name "SmithsLogging.psm1"
  Start-SmithsLog -Component "Connect to Azure AD PowerShell" -LogRun:$false -ReadOnly:$ReadOnly

  Import-SmithsModule -Name "SmithsAzureAD.psm1"

  Connect-SmithsAAD

  Stop-SmithsLog
}


main
