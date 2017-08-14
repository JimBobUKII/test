[CmdletBinding()]
Param()

$adminRoles = Get-SmithsConfigGroupSetting -Component "Office 365 Admin Roles"
$script:successes = 0
$script:failures = 0
$script:unchanged = 0
$script:deferred = 0
$script:activity = "Office 365 Admin Roles"

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


  # Foreach role in the admin roles in the config file

  Foreach($role in $adminRoles){

    $roleGroup = Get-MsolRole -RoleName $role.Name

    # Get recursive group membership from AD
    # extensionAttribute1 holds the user's cloud admin UPN (jchqdgee-ca@smithsonline.onmicrosoft.com)
    #

    $groupMembers = [Object[]]($role | Select -ExpandProperty Include | Get-SmithsADGroupMember -Properties @("extensionAttribute1") | Select -ExpandProperty extensionAttribute1 |% { Get-MsolUser -UserPrincipalName $_ } | Select UserPrincipalName, ObjectId)

    $cloudRoleMembers = [Object[]](Get-MsolRoleMember -RoleObjectId $roleGroup.ObjectId -MemberObjectTypes User | Select ObjectId, @{Label="UserPrincipalName";expression={$_.EmailAddress}})

    # Determine which users who already have provisioned cloud admin accounts
    # need adding and removing from the appropriate Exchange Online role group
    # Then make the appropriate changes

    $needAdding = [Object[]]($groupMembers | Where { $_.ObjectId -notin $cloudRoleMembers.ObjectId } | Select ObjectId, UserPrincipalName)
    $needRemoving = [Object[]]($cloudRoleMembers | Where { $_.ObjectId  -notin $groupMembers.ObjectId } | Select ObjectId, UserPrincipalName)

    If($needAdding.Count -gt 0){
      $roleObj = [PSCustomObject]@{Name = $role.Name; ObjectId = $roleGroup.ObjectId}
      Write-SmithsLog -Level INFO -Activity $script:activity -Message "Adding $($needAdding.Count) cloud admins to '$($role.Name)' role"
      $needAdding | Set-SmithsO365RoleMember -Role $roleObj -ReadOnly:$ReadOnly -Action "Add"
    }
    Else {
      Write-SmithsLog -Level INFO -Activity $script:activity -Message "No cloud admins to add to '$($role.Name)' role"
    }
    If($needRemoving.Count -gt 0){
      $roleObj = [PSCustomObject]@{Name = $role.Name; ObjectId = $roleGroup.ObjectId}
      Write-SmithsLog -Level INFO -Activity $script:activity -Message "Removing $($needRemoving.Count) cloud admins from '$($role.Name)' role"
      $needRemoving | Set-SmithsO365RoleMember -Role $roleObj -ReadOnly:$ReadOnly -Action "Remove"
    }
    Else {
      Write-SmithsLog -Level INFO -Activity $script:activity -Message "No cloud admins to remove from '$($role.Name)' role"
    }
  }
}

Function Get-Priority {

  [CmdletBinding()]
  Param()

  10

}



