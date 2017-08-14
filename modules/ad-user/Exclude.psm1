[CmdletBinding()]
Param()

$emailRegex = Get-SmithsConfigSetting -Component "Global" -Name "Email Regex"
$inactiveOUs = Get-SmithsConfigSetting -Component "Active Directory" -Name "Inactive OUs"
$excludeSites = Get-SmithsConfigSetting -Component "Active Directory" -Name "Exclude Sites"
$siteCodeRegex = Get-SmithsConfigSetting -Component "Active Directory" -Name "Site Code Regex"
$USER_STAMP = Get-SmithsConfigSetting -Component "Active Directory" -Name "User Do Not Sync"
$licenseGroups = Get-SmithsConfigGroupSetting -Component "Licensing" | Select -ExpandProperty Include
$script:activity = "Exclude"

Function Get-Changes {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser]$User
  )


  $dn = Get-DNComponents -DistinguishedName $User.DistinguishedName
  $upn = $User.UserPrincipalName
  $samaccountname = $User.SamAccountName
  $curVal = $User.adminDescription
  $hasInternalAddress = 

  # Default behaviour is not to stamp users
  $stamp = $false
  # Allows for manual override using ea4
  $manual = $false
  # $dn[0] == CN=something
  # $dn[1] == parent OU
  # ...
  # $dn[-7] == OU=<SiteCode> Users
  # $dn[-6] == OU=<SiteCode>
  # $dn[-5] == OU=<Division>
  # $dn[-4] == OU=<Region>
  # $dn[-3] == OU=Regions
  # $dn[-2] == DC=smiths
  # $dn[-1] == DC=net
  If((Compare-DNSegment -DN $dn -Segment -3 -Value "OU=Regions")){
    # Leave users in the Inactive OUs the way there are
    If((Compare-DNSegment -DN $dn -Segment -5 -Values $inactiveOUs)){
      $reason = "in an Inactive Users OU"
    }
    ElseIf((Compare-DNSegment -DN $dn -SEgment -4 -Value "^OU=Global$")){
      $reason = "in a Global OU"
      $stamp = $true
    }
    Else {
      # Any user not in an XXXX Users OU should be stamped to exclude from sync
      If((Compare-DNSegment -DN $dn -Segment -7 -Value "^OU=$siteCodeRegex Users$") -and (Compare-DNSegment -DN $dn -Segment -6 -Value "^OU=$siteCodeRegex$")){
        $reason = "a regular user"
      }
      Else {
        $reason = "not in a Site Code Users OU"
        $stamp = $true
      }
    }
  }
  # Exclude all users outside the Regions OU
  Else {
    $reason = "not in the Regions OU"
    $stamp = $true
  }

  # Finally, if a user has a shared mailbox attribute set, don't ever stamp it.
  If($User.extensionAttribute4 -in @("Room", "Shared", "Equipment")){
    $stamp = $false
    $reason = "is a $($User.extensionAttribute4.ToLower()) mailbox"
  }

  If(($User.memberOf | Where { $_ -in $licenseGroups }).Count -gt 0){
    $stamp = $false
    $reason = "has a license assigned"
  }

  If($User.title -eq "Resource Mailbox" -and $User.mail -match $emailRegex){
    $stamp = $false
    $reason = "is a resource mailbox"
  }

  # If the user is in one of the exclude sites (e.g. SSA), stamp it
  If($User.physicalDeliveryOfficeName -in $excludeSites){
    $stamp = $true
    $reason = "is in an excluded OU"
  }
  Switch($User.extensionAttribute4){
    "Sync" {
      $stamp = $false
      $reason = "is marked to sync"
    }
    "Block" {
      $stamp = $true
      $reason = "is marked to block"
    }
    "Manual" {
      $manual = $true
      $reason = "is marked as manual"
    }
    "GAL" {
      If(-not (Test-SmithsAADAddress -Address $User.mail)){
        $stamp = $false
        $reason = "GAL entry (no mailbox)"
      }
    }
  }


  If(-not $manual){
    If($stamp){
      # apply the stamp
      Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Message "Exclude, account $reason." -Activity $script:activity
      @{adminDescription = @{Type = "Set"; Value = $USER_STAMP}}
    }
    Else {
      If($User.adminDescription -match $USER_STAMP){
        # clear the stamp if it is set
        Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Message "Do not exclude, account $reason." -Activity $script:activity
        @{adminDescription = @{Type = "Set"; Value = $null}}
      }
      Else {

        # no changes
        Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Message "Do not exclude, no changes necessary, $reason." -Activity $script:activity
      }
    }
  }
  Else {
    Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Message "Skipping, $reason." -Activity $script:activity
  }
}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  @("adminDescription", "extensionAttribute4", "physicalDeliveryOfficeName", "title", "mail", "memberOf")

}


Function Get-Priority {

  [CmdletBinding()]
  Param()

  40

}
