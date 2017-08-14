[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$SiteCode,
  [Hashtable]$Settings,
  [string]$Path = "$PSScriptRoot/../shared-mailboxes/$($SiteCode.ToLower()).csv"
)

Function Get-SharedMailboxes {

  $searchbase = Get-SmithsConfigSetting -Component "Active Directory" -Name "Search Base"
  $credential = Get-SmithsConfigSetting -Component "Active Directory" -Name "Credential"

  $attributesToLoad = [string[]]@(
    "DisplayName"
    "extensionAttribute4",
    "physicalDeliveryOfficeName"
  )

  Write-SmithsLog -Level DEBUG -Activity "AD Search" -Message "Finding OU"

  $ou = Get-ADOrganizationalUnit -LDAPFilter "(ou=$SiteCode)" -SearchBase $searchbase

  Write-SmithsLog -Level DEBUG -Activity "AD Search" -Message "Finding shared/resource mailboxes in $($ou.DistinguishedName)"

  $users = [Microsoft.ActiveDirectory.Management.ADAccount[]](Get-ADUser -LDAPFilter "(extensionAttribute4=*)" -Properties $attributesToLoad -SearchBase $ou.DistinguishedName)
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

