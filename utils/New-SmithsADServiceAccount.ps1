<#
.SYNOPSIS
    Creates O365 test users
.DESCRIPTION

.NOTES
    Author: David Gee

    Version History:
    Version   Date        Author                Changes
    1.0       09/09/2016  David Gee             Initial release
#>
[CmdletBinding()]
Param(
  [switch]$ReadOnly,
  [string]$Password,
  $i
)


Function New-O365TestUser {

  $credential = Get-SmithsConfigSetting -Component "Active Directory" -Name "Credential"

    $properties = @{
      Name = "Office 365, Test User $i (JCHQ)"
      AccountPassword = (ConvertTo-SecureString -String $password -AsPlainText -Force)
      Company = "SMITHS BIS INC"
      Description = "Office 365 test account"
      DisplayName = "Office 365, Test User $i (JCHQ)"
      Division = "BIS"
      Enabled = $true
      GivenName = "Test User $i"
      Manager = "jchqdgee"
      Path = "OU=JCHQ Users,OU=JCHQ,OU=John Crane,OU=US,OU=Regions,DC=smiths,DC=net"
      SamAccountName = "jchqo365test$i"
      Surname = "Office 365"
      UserPrincipalName = "office365.testuser$i@smiths.com"
    }

    If(-not $ReadOnly){
      New-ADUser -Credential $Credential @properties
    }



}

Function main {

  Import-Module -Name (Resolve-Path -Path "$PSScriptRoot/../modules/Smiths.psm1") -Force
  Import-SmithsConfig -Overrides $Settings

  New-O365TestUser
}


main



