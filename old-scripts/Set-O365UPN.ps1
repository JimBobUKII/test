<#
.SYNOPSIS
    Updates UPNs to match the primary mail address.
.DESCRIPTION
    Based on input supplied in a text file, AD accounts are updated so that the UPN matches the primary mail address.
    The text file should have one username per line.
.NOTES
    Author: David Gee

    Version History:
    Version   Date        Author                Changes
    1.0       09/09/2016  David Gee             Initial release
#>
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)]
  [ValidateScript({Test-Path $_})]
  [ValidateNotNullOrEmpty()]
  $Userfile
)

Function main {
  Import-Module -Name (Join-Path $PSScriptRoot "O365.psm1") -Force
  Import-Module -Name (Join-Path $PSScriptRoot "O365Logging.psm1") -Force

  $upnsuffixes = (Get-ADForest).UPNSuffixes

  $users = Get-Content $Userfile

  $updates = @{}

  Foreach($user in $users){

    Try {
      $userObject = Get-ADUser -Identity $user -Properties mail

      # Split the primary e-mail address into user and domain components
      ($mailuser, $maildomain) = $userObject.mail -split "@"

      # Check to make sure the e-mail address domain is in the list of valid UPN suffixes
      If($maildomain -notin $upnsuffixes){
        throw "Cannot find the UPN suffix '$maildomain' for user '$($userObject.Name)'"
      }

      $check = Get-ADObject -LdapFilter "(mail=$($userObject.mail))"
      If($check.Count -gt 1){
        throw "Duplicate objects exist in AD with primary e-mail address '$($userObject.mail)'"
      }

      Write-SmithsLog -Level DEBUG -Message "ok to proceed for '$user'"


    }
    Catch {
      # Cannot find user - write error, continue
      Write-SmithsLog -Level ERROR -Message $_.Exception.Message
    }

  }



}


main
