<#
.SYNOPSIS
    Master script to update User Principal Names in O365 when they change.
.DESCRIPTION
  For each user in AD, checks to see whether the UPN exists on cloud. If not,
  it finds it (looking it up using the sourceAnchor, calculated from the
  objectGUID) and then updates to an on-cloud UPN. Azure AD Connect will then
  set the correct UPN on the next delta sync.
.NOTES
    Author: David Gee

    Version History:
    Version   Date        Author                Changes
    1.0       09/09/2016  David Gee             Initial release
#>
[CmdletBinding()]
Param(
  [switch]$ReadOnly,
  [switch]$TestUsers,
  [string]$CustomFilter = "",
  [switch]$UpdateAll
)

Function Update-UPNs {

  $successcount = 0
  $failurecount = 0
  $skipcount = 0

  $searchbase = Get-SmithsConfigSetting -Component "Active Directory" -Name "Search Base"
  $credential = Get-SmithsConfigSetting -Component "Active Directory" -Name "Credential"
  $excludeSites = Get-SmithsConfigSetting -Component "Active Directory" -Name "Exclude Sites"
  $modulePath = Get-SmithsConfigSetting -Component "Active Directory" -Name "User Modules"

  $ldapFilter = Get-SmithsADLDAPFilter -ObjectType "USER" -TestUsers:$TestUsers -UpdateAll:$UpdateAll -CustomFilter:$CustomFilter

  $users = Get-ADUser -LDAPFilter $ldapFilter -SearchBase $searchbase

  # Get list of all O365 users. Quicker to do this once than call once per user.

  Write-SmithsLog -Level DEBUG -Message "Getting list of all O365 users"
  #$msolUsers = Get-MSOLUser -All
  $msolUsers = Get-MsolUser -UserPrincipalName "office365.testuser2@smiths.com"

  # For determining the default DNS suffix
  $defaultDomain = (Get-MsolDomain | Where { $_.IsDefault }).Name

  Foreach($adUser in $users){

    #
    # Try to get user by UPN first

    $msolUser = $msolUsers | Where { $_.UserPrincipalName -eq $adUser.UserPrincipalName }
    Write-Host "First Msol user is null $($msolUser -eq $null)"

    If($msolUser -eq $null){

      # If null, user wasn't found with this UPN, implying UPN change
      # Find actual user object on cloud


      # Find the user from the sourceAnchor

      $sourceAnchor = [Convert]::ToBase64String($adUser.ObjectGUID.ToByteArray())
      $msolUser = $msolUsers | Where { $_.ImmutableID -eq $sourceAnchor } -ErrorAction SilentlyContinue

      If($msolUser -ne $null){

        # If not null, the user was found - this is what we expect to happen
        # Calculate the new UPN using the sAMAccountName and default domain (@xxx.onmicrosoft.com)

        $newUPN = "$($adUser.SamAccountName)@$defaultDomain"

        Write-SmithsLog -Level DEBUG -Message "Setting cloud UPN for user '$($adUser.UserPrincipalName)' to '$newUPN', previous value = '$($msolUser.UserPrincipalName)'"

        # Update the UPN, and set a random password

        Set-MsolUserPrincipalName -ObjectId $msolUser.ObjectId -NewUserPrincipalName $newUPN -NewPassword

      }
      Else {
        Write-SmithsLog -Level WARN -Message "Cannot find O365 user with Immutable ID $sourceAnchor"
      }

    }

  }
}

Function main {

  Import-Module -Name "$PSScriptRoot/O365.psm1" -Force
  Import-Module -Name "$PSScriptRoot/O365Logging.psm1" -Force
  Import-Module -Name "$PSScriptRoot/O365ActiveDirectory.psm1" -Force

  Import-SmithsConfig

  Connect-SmithsO365

  Update-UPNs

}


main


