[CmdletBinding()]
Param(
  [Hashtable]$Settings
)

Function main {

  Import-Module -Name (Resolve-Path -Path "$PSScriptRoot/../modules/Smiths.psm1") -Force
  Import-SmithsConfig -Overrides $Settings

  Import-SmithsModule -Name "SmithsAD.psm1"

  Get-SmithsConfigSetting -Component "Active Directory" -Name "Credential"

}


main

