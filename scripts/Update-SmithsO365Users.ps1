[CmdletBinding()]
Param(
  [switch]$ReadOnly,
  [string]$CustomFilter = "",
  [switch]$UpdateAll,
  [string[]]$ModuleList,
  [Hashtable]$Settings
)

Function Update-O365Users {

  $modulePath = Get-SmithsConfigSetting -Component "Office 365" -Name "User Modules"
  # Returns a sorted list in priority order

  $modules = Import-SmithsDynamicModules -Path $modulePath -ModuleList $ModuleList

  Write-SmithsLog -Level DEBUG -Activity "Office 365 Search" -Message "Fetching Office 365 users"
  $msolUsers = Get-MsolUser -Synchronized -All | Select ObjectId,ImmutableId,UserPrincipalName,@{label="Licenses";expression={$_.Licenses.AccountSkuId}}
  Write-SmithsLog -Level DEBUG -Activity "Office 365 Search" -Message "Found $($msolUsers.Count) Office 365 users"

  Write-SmithsLog -Level DEBUG -Activity "AD Search" -Message "Fetching AD users"
  $searchbase = Get-SmithsConfigSetting -Component "Active Directory" -Name "Search Base"
  $attributes = Invoke-SmithsDynamicModuleFunctionForAll -Function "Get-Attributes"
  $adUsers = Get-ADUser -LDAPFilter "(&(samaccounttype=805306368)(!(adminDescription=User_DoNotSyncO365)))" -SearchBase $searchbase -Properties $attributes
  Write-SmithsLog -Level DEBUG -Activity "AD Search" -Message "Found $($adUsers.Count) AD users"


  Invoke-SmithsDynamicModuleFunctionForAll -Function "Update-CloudUsers" -ArgumentList @{
    CloudUsers = $msolUsers
    Users = $adUsers
    ReadOnly = $ReadOnly
  }

}

Function main {

  Import-Module -Name (Resolve-Path -Path "$PSScriptRoot/../modules/Smiths.psm1") -Force
  Import-SmithsConfig -Overrides $Settings

  Import-SmithsModule -Name "SmithsLogging.psm1"
  Start-SmithsLog -Component "O365 User Update" -LogRun:$false -ReadOnly:$ReadOnly

  Import-SmithsModule -Name "SmithsO365.psm1"
  Import-SmithsModule -Name "SmithsDynamicModules.psm1"
  Import-SmithsModule -Name "SmithsAD.psm1"

  Connect-SmithsO365

  Update-O365Users

  Stop-SmithsLog
}


main

