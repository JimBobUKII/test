[CmdletBinding()]
Param(
  [switch]$ReadOnly,
  [string[]]$ModuleList,
  [Hashtable]$Settings
)

Function Update-SmithsCloudAdmins {

  # Returns a sorted list in priority order
  $modulePath = Get-SmithsConfigSetting -Component "Cloud Admins" -Name "Admin Modules"
  $modules = Import-SmithsDynamicModules -Path $modulePath -ModuleList $ModuleList
  $adCredential = Get-SmithsConfigSetting -Component "Active Directory" -Name "Credential"

  $result = Invoke-SmithsDynamicModuleFunctionForAll -Function "Update-CloudAdmins" -ArgumentList @{
    ReadOnly = $ReadOnly
    Credential = $adCredential
  }
}

Function main {

  Import-Module -Name (Resolve-Path -Path "$PSScriptRoot/../modules/Smiths.psm1") -Force
  Import-SmithsConfig -Overrides $Settings

  Import-SmithsModule -Name "SmithsLogging.psm1"
  Start-SmithsLog -Component "Cloud Admin Update" -LogRun:$false -ReadOnly:$ReadOnly

  Import-SmithsModule -Name "SmithsAD.psm1"
  Import-SmithsModule -Name "SmithsDynamicModules.psm1"
  Import-SmithsModule -Name "SmithsO365.psm1"

  Connect-SmithsO365

  Update-SmithsCloudAdmins

  Stop-SmithsLog
}


main

