[CmdletBinding()]
Param()

$adminRoles = Get-SmithsConfigGroupSetting -Component "Security and Compliance Admin Roles"
$script:successes = 0
$script:failures = 0
$script:unchanged = 0
$script:deferred = 0
$script:activity = "Security and Compliance Admin Roles"

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

  Import-SmithsModule -Name "SmithsSecurityCompliance.psm1"
  Connect-SmithsSecurityCompliance

  # Foreach role in the admin roles in the config file

  Foreach($role in $adminRoles){

    # Get recursive group membership from AD
    # extensionAttribute1 holds the user's cloud admin UPN (jchqdgee-ca@smithsonline.onmicrosoft.com)

    $groupMembers = [string[]]($role | Select -ExpandProperty Include | Get-SmithsADGroupMember -Properties @("extensionAttribute1") | Select -ExpandProperty extensionAttribute1)

    # Get the list of cloud admins currently assigned to the role group in Security and Compliance
    # The WindowsLiveId property holds the O365 UPN of the user in Security and Compliance

    $cloudRoleMembers = [string[]](Get-SCRoleGroupMember -Identity $role.Name | Select -ExpandProperty WindowsLiveId)

    # Determine which users who already have provisioned cloud admin accounts
    # need adding and removing from the appropriate Security and Compliance role group
    # Then make the appropriate changes

    $needAdding = [string[]]($groupMembers | Where { $_ -notin $cloudRoleMembers })
    $needRemoving = [string[]]($cloudRoleMembers | Where { $_ -notin $groupMembers })

    If($needAdding.Count -gt 0){
      Write-SmithsLog -Level INFO -Activity $script:activity -Message "Adding $($needAdding.Count) cloud admins to '$($role.Name)' role"
      $needAdding | Set-SmithsSecurityComplianceRole -Role $role.Name -ReadOnly:$ReadOnly -Action "Add"
    }
    Else {
      Write-SmithsLog -Level INFO -Activity $script:activity -Message "No cloud admins to add to '$($role.Name)' role"
    }
    If($needRemoving.Count -gt 0){
      Write-SmithsLog -Level INFO -Activity $script:activity -Message "Removing $($needRemoving.Count) cloud admins from '$($role.Name)' role"
      $needRemoving | Set-SmithsSecurityComplianceRole -Role $role.Name -ReadOnly:$ReadOnly -Action "Remove"
    }
    Else {
      Write-SmithsLog -Level INFO -Activity $script:activity -Message "No cloud admins to remove from '$($role.Name)' role"
    }
  }

  Disconnect-SmithsSecurityCompliance
}

Function Get-Priority {

  [CmdletBinding()]
  Param()

  30

}



