[CmdletBinding()]
Param()

$inactiveOUs = Get-SmithsConfigSetting -Component "Active Directory" -Name "Inactive OUs"
$siteCodeRegex = Get-SmithsConfigSetting -Component "Active Directory" -Name "Site Code Regex"
$script:activity = "Site Code"

Function Get-Changes {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser]$User
  )

  $dn = Get-DNComponents -DistinguishedName $User.DistinguishedName
  $upn = $User.UserPrincipalName
  $currentSiteCode = $User.physicalDeliveryOfficeName
  $newSiteCode = ""
  $username = $User.SamAccountName


  # $dn[0] == CN=something
  # $dn[1] == parent OU
  # ...
  # $dn[-3] == next level OU
  # $dn[-2] == DC=smiths
  # $dn[-1] == DC=net
  $setSiteCode = $true
  If((Compare-DNSegment -DN $dn -Segment -3 -Value "OU=Regions")){

    # User lives somewhere in the Regions OU

    If((Compare-DNSegment -DN $dn -Segment -5 -Values $inactiveOUs)){

      # Inactive users do not live in a site code OU, so handle differently

      $reason = "account in an Inactive Users OU"
      If($User.physicalDeliveryOfficeName -ne $null -and $User.physicalDeliveryOfficeName -ne ""){

        # If site code is blank, set it to the first four chars of the username

        $newSiteCode = $username.Substring(0, 4).ToUpper()
      }
      Else {

        # Otherwise, do not change it (assume it was previously set when the user was active)

        $setSiteCode = $false
      }
    }
    ElseIf((Compare-DNSEgment -DN $dn -Segment -4 -Value "^OU=Global$")){

      # Global OU - service accounts and whatnot

      $setSiteCode = $false
      $reason = "account is in a Global OU"
    }
    Else {

      # User is in regions, but not in Inactive Users OU or Global OU
      If((Compare-DNSegment -DN $dn -Segment -6 -Value "^OU=${siteCodeRegex}$")){

        # User is in well-defined site code OU
        # OK, use it

        $siteCode = Get-DNSegment -DN $dn -Segment -6
        $newSiteCode = $siteCode.Substring(3,4).ToUpper()
        $reason = "account is in a Site Code Users OU"
      }
      Else {

        # User is not in inactive users OU and is not in well-defined site code OU
        # Don't set site code
        $reason = "account is elsewhere in Regions OU"
        $setSiteCode = $false
      }
    }
  }

  # Exclude all users outside the Regions OU

  Else {
    $reason = "account is outside Regions OU"
    $setSiteCode = $false
  }

  # Return the new site code only if setSiteCode = $true

  If($setSiteCode){
    Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Message "Setting site code = '$newSiteCode', $reason" -Activity $script:activity
    @{physicalDeliveryOfficeName = @{Type = "Set"; Value = $newSiteCode}}
  }
  Else {
    Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Message "$reason, skipping" -Activity $script:activity
  }
}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  @("physicalDeliveryOfficeName")

}


Function Get-Priority {

  [CmdletBinding()]
  Param()

  30

}
