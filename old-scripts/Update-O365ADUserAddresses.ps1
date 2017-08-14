<#
.SYNOPSIS
    Master script to update AD users for O365.
.DESCRIPTION
    Scans AD for users and groups that do not have an exclusion flag in place. Sets
    the flag for any users that are located outside of a standard users OU.
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
  [string]$InputFile
)

Function Update-Users {

  $successcount = 0
  $failurecount = 0
  $skipcount = 0

  $searchbase = Get-SmithsConfigSetting -Component "Active Directory" -Name "Search Base"
  $credential = Get-SmithsConfigSetting -Component "Active Directory" -Name "Credential"

  $ldapFilter = Get-SmithsADLDAPFilter -ObjectType "USER" -TestUsers:$TestUsers -UpdateAll

  $attributesToCopy = @("streetaddress","l","st","postalCode","c","mobile","telephoneNumber","facsimileTelephoneNumber","homePhone")
  $attributesToLoad = @("samaccountname","givenname","sn","displayname","mail") + $attributesToCopy

  #$adUsers = Get-ADUser -LDAPFilter $ldapFilter -Properties $attributesToLoad -SearchBase $searchbase
  $resourceUsers = Import-CSV -Path $InputFile
  $i = 0
  Foreach($resourceUser in $resourceUsers){
    Write-SmithsProgress -Activity "Updating smithsnet users" -Status $resourceUser.samaccountname -Item $i -Count $resourceUsers.Count

    $changes = @{}

    #$adUser = $adUsers | Where { $_.SamAccountName -eq $resourceUser.samaccountname }
    Try {
      $adUser = Get-ADUser -Identity $resourceUser.samaccountName -Properties $attributesToLoad -ErrorAction Stop

      Foreach($attr in $attributesToCopy){
        If($resourceUser.$attr -ne $null -and $resourceUser.$attr.Trim() -ne ""){
          $changes.$attr = @{Type = "Set"; Value = $resourceUser.$attr.Trim()}
        }
      }

      $Params = @{
        "-Identity" = $adUser.SamAccountName
        "-Changes" = $changes
        "-ReadOnly" = $ReadOnly
        "-Credential" = $credential
        "-ObjectType" = "USER"
        "-Object" = $adUser
      }
      $success, $failure, $skip = Set-SmithsADObject @params
    }
    Catch {
      $adUser = $null
      Write-SmithsLog -Level ERROR -Message "[AD UPDATE ERROR] No such user '$($resourceUser.samaccountname)': $($_.Exception.Message)"
      $success, $failure, $skip = 0, 1, 0
    }

    $i++

    $successcount += $success
    $failurecount += $failure
    $skipcount += $skip
    #>
  }
  Write-SmithsLog -Level INFO -Message "[AD UPDATE COMPLETE] $successcount successes, $failurecount failures, $skipcount skipped"
}

Function main {

  Import-Module -Name "$PSScriptRoot/O365.psm1" -Force
  Import-Module -Name "$PSScriptRoot/O365Logging.psm1" -Force
  Import-Module -Name "$PSScriptRoot/O365ActiveDirectory.psm1" -Force

  Import-SmithsConfig

  Update-Users
}


main
