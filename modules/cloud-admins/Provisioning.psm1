[CmdletBinding()]
Param()

$adminRoles = Get-SmithsConfigGroupSetting -Component "Cloud Admin Provisioning"
$script:successes = 0
$script:failures = 0
$script:unchanged = 0
$script:deferred = 0
$script:activity = "Cloud Admin Provisioning"

Function Update-CloudAdmins {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [switch]$ReadOnly,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [PSCredential]$Credential
  )

  # Identify AD users in one of the AD groups used for cloud admins

  $adminsAssigned = [Microsoft.ActiveDirectory.Management.ADUser[]]($adminRoles | Select -ExpandProperty Include | Get-SmithsADGroupMember -Properties @("mail", "extensionAttribute1","msExchUsageLocation"))


  # Identify users with a cloud admin account defined in AD

  $adAdmins = [Microsoft.ActiveDirectory.Management.ADUser[]](Get-ADUser -LDAPFilter "(extensionAttribute1=*)" -Properties extensionAttribute1)

  # Identify users who have already been provisioned:
  #   ExtensionAttribute1 is populated with the cloud admin UPN (jchqdgee-ca@smithsonline.onmicrosoft.com)
  #   The UPN actually exists in Office 365

  $adminsInCloud = [string[]]($adAdmins |% { Get-MsolUser -UserPrincipalName $_.extensionAttribute1 -ErrorAction SilentlyContinue } | Select -ExpandProperty UserPrincipalName)

  # Identify users that need provisioning (not already in cloud)

  $needsProvisioning = [Microsoft.ActiveDirectory.Management.ADUser[]]($adminsAssigned | Where { $_.Enabled -and ($_.ExtensionAttribute1 -eq $null -or $_.ExtensionAttribute1 -notin $adminsInCloud) })

  # Identify users that need deprovisioning because
  #   The user account in AD has been disabled
  #   The user is no longer in an AD cloud admin group

  $needsDeprovisioning = [Microsoft.ActiveDirectory.Management.ADUser[]]($adAdmins | Where { $_.ExtensionAttribute1 -in $adminsInCloud -and ((-not $_.Enabled) -or $_.UserPrincipalName -notin $adminsAssigned.UserPrincipalName) })


  # Deprovision accounts and log

  If($needsDeprovisioning.Count -gt 0){
    If($needsDeprovisioning.Count -eq 1){
      $msg = "1 cloud admin account requires deprovisioning"
    }
    Else {
      $msg = "$($needsDeprovisioning.Count) cloud admin accounts require deprovisioning"
    }
    Write-SmithsLog -Level INFO -Activity $script:activity -Message $msg
    $newlyDeprovisionedAdmins = $needsDeprovisioning | Remove-SmithsO365CloudAdmin -ReadOnly:$ReadOnly -Credential $Credential
  }
  Else {
    Write-SmithsLog -Level INFO -Activity $script:activity -Message "No users require cloud admin accounts deprovisioning"
  }

  # Provision accounts and log
  # The provisioning process will e-mail users informing them of their new credentials

  If($needsProvisioning.Count -gt 0){
    If($needsProvisioning.Count -eq 1){
      $msg = "1 cloud admin account requires provisioning"
    }
    Else {
      $msg = "$($needsProvisioning.Count) cloud admin accounts require provisioning"
    }
    $newlyProvisionedAdmins = $needsProvisioning | New-SmithsO365CloudAdmin -Credential $Credential -ReadOnly:$ReadOnly
  }
  Else {
    Write-SmithsLog -Level INFO -Activity $script:activity -Message "No users require cloud admin accounts provisioning"
  }
}

Function Get-Priority {

  [CmdletBinding()]
  Param()

  5

}




