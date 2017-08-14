[CmdletBinding()]
Param(
  [Hashtable]$Settings,
  [string]$CustomFilter,
  [string]$Path
)

Function Get-SharedMailboxes {

  $searchbase = Get-SmithsConfigSetting -Component "Active Directory" -Name "Search Base"
  $credential = Get-SmithsConfigSetting -Component "Active Directory" -Name "Credential"

  $attributesToLoad = [string[]]@(
    "DisplayName"
    "extensionAttribute4",
    "physicalDeliveryOfficeName"
  )

  Write-SmithsLog -Level DEBUG -Activity "AD Search" -Message "Finding shared/resource mailboxes with filter $CustomFilter"

  $users = [Microsoft.ActiveDirectory.Management.ADAccount[]](Get-ADUser -LDAPFilter "(&(extensionAttribute4=*)($CustomFilter))" -Properties $attributesToLoad -SearchBase $searchbase)
  $count = $users.Count

  Write-SmithsLog -Level INFO -Activity "AD Search" -Message "$count mailboxes found"

  $users | Select samaccountname, displayname, @{label="newdn";expression={$_.displayname}}, extensionattribute4, @{label="newea4";expression={$_.extensionattribute4}}, physicalDeliveryOfficeName | Export-CSV -NoTypeInformation -Encoding utf8 -Path $Path

}

Function main {

  Import-Module -Name (Resolve-Path -Path "$PSScriptRoot/../modules/Smiths.psm1") -Force
  Import-SmithsConfig -Overrides $Settings

  Import-SmithsModule -Name "SmithsLogging.psm1"
  $script:lastrun = Start-SmithsLog -Component "AD User Update" -LogRun:$false -ReadOnly:$ReadOnly

  Import-SmithsModule -Name "SmithsAD.psm1"

  Get-SharedMailboxes

  Stop-SmithsLog
}


main

