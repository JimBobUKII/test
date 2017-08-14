[CmdletBinding()]
Param(
  [switch]$ReadOnly,
  [string[]]$ModuleList,
  [Hashtable]$Settings
)

Function Update-SmithsExchangeOnlineSelectedUsers {

  # Returns a sorted list in priority order
  $modulePath = Get-SmithsConfigSetting -Component "Exchange Online" -Name "Subset Modules"
  $modules = Import-SmithsDynamicModules -Path $modulePath -ModuleList $ModuleList

  $result = Invoke-SmithsDynamicModuleFunctionForAll -Function "Update-Mailboxes" -ArgumentList @{ReadOnly = $ReadOnly}
}

Function main {

  Import-Module -Name (Resolve-Path -Path "$PSScriptRoot/../modules/Smiths.psm1") -Force
  Import-SmithsConfig -Overrides $Settings

  Import-SmithsModule -Name "SmithsLogging.psm1"
  Start-SmithsLog -Component "Exchange Online User Update" -LogRun:$false -ReadOnly:$ReadOnly

  Import-SmithsModule -Name "SmithsExchangeOnline.psm1"
  Import-SmithsModule -Name "SmithsDynamicModules.psm1"
  Import-SmithsModule -Name "SmithsAD.psm1"

  Connect-ExchangeOnline -ProxyRPS

  Update-SmithsExchangeOnlineSelectedUsers

  Stop-SmithsLog
}


main


