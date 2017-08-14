[CmdletBinding()]
Param(
  [switch]$ReadOnly,
  [switch]$UpdateAll,
  [string]$CustomFilter = "",
  [string[]]$ModuleList,
  [Hashtable]$Settings
)

Function Update-ExchangeOnlineUsers {

  $successcount = 0
  $failurecount = 0
  $skipcount = 0



  # Returns a sorted list in priority order
  $modulePath = Get-SmithsConfigSetting -Component "Exchange Online" -Name "User Modules"
  $modules = Import-SmithsDynamicModules -Path $modulePath -ModuleList $ModuleList

  Write-SmithsLog -Level INFO -Activity "Exchange Online Search" -Message "Retrieving all mailboxes"
  $mailboxes = Get-Mailbox -ResultSize Unlimited
  Write-smithsLog -Level INFO -Activity "Exchange Online Search" -Message "Found $($mailboxes.Count) mailboxes"

  Write-SmithsLog -Level INFO -Activity "Exchange Online Search" -Message "Retrieving all CAS mailboxes"
  $casMailboxes = Get-CASMailbox -ResultSize Unlimited
  Write-smithsLog -Level INFO -Activity "Exchange Online Search" -Message "Found $($casMailboxes.Count) CAS mailboxes"

  If($mailboxes.Count -ne $casMailboxes.Count){
    Write-smithsLog -Level WARN -Activity "Exchange Online Search" -Message "Count of mailboxes and CAS mailboxes differs"
  }
  $result = Invoke-SmithsDynamicModuleFunctionForAll -Function "Update-CloudObjects" -ArgumentList @{
    Mailboxes = $mailboxes
    CASMailboxes = $casMailboxes
    ReadOnly = $ReadOnly
    UpdateAll = $UpdateAll
  }

  Remove-Variable -Name @("mailboxes", "casMailboxes")
}

Function main {

  Import-Module -Name (Resolve-Path -Path "$PSScriptRoot/../modules/Smiths.psm1") -Force
  Import-SmithsConfig -Overrides $Settings

  Import-SmithsModule -Name "SmithsLogging.psm1"
  Start-SmithsLog -Component "Exchange Online User Update" -LogRun:$false -ReadOnly:$ReadOnly

  Import-SmithsModule -Name "SmithsExchangeOnline.psm1"
  Import-SmithsModule -Name "SmithsAD.psm1"
  Import-SmithsModule -Name "SmithsO365.psm1"
  Import-SmithsModule -Name "SmithsDynamicModules.psm1"

  Connect-SmithsO365
  Connect-ExchangeOnline

  Update-ExchangeOnlineUsers

  Stop-SmithsLog
}


main

