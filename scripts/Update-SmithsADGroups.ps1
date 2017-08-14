<#
.SYNOPSIS
    Master script to update AD groups for O365.
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
  [switch]$TestGroups,
  [string]$CustomFilter = "",
  [switch]$UpdateAll,
  [Hashtable]$Settings
)

Function Update-SmithsADGroups {

  $successcount = 0
  $failurecount = 0
  $skipcount = 0

  $searchbase = Get-SmithsConfigSetting -Component "Active Directory" -Name "Search Base"
  $credential = Get-SmithsConfigSetting -Component "Active Directory" -Name "Credential"
  $excludeSites = Get-SmithsConfigSetting -Component "Active Directory" -Name "Exclude Sites"
  $modulePath = Get-SmithsConfigSetting -Component "Active Directory" -Name "Group Modules"

  $modules = Import-SmithsDynamicModules -Path $modulePath
  $attributesToLoad = $modules | Invoke-SmithsDynamicModuleFunction -Function "Get-Attributes" | Select -Unique

  $ldapFilter = Get-SmithsADLDAPFilter -ObjectType "GROUP" -TestGroups:$TestGroups -UpdateAll:$UpdateAll -CustomFilter:$CustomFilter -LastRun $script:lastrun
  Write-SmithsLog -Level DEBUG -Activity "AD Search" -Message "AD Search filter: $ldapFilter"
  Write-SmithsLog -Level DEBUG -Activity "AD Search" -Message "Starting AD search"

  $groups = Get-ADGroup -LDAPFilter $ldapFilter -Properties $attributesToLoad -SearchBase $searchbase
  If($users -is [Microsoft.ActiveDirectory.Management.ADAccount]){
    $count = 1
  }
  Else {
    $count = $groups.Count
  }

  Write-SmithsLog -Level INFO -Activity "AD Search" -Message "$count groups found"

  Foreach($group in $groups){

    $changes = @{}

    Foreach($module in $modules){

      Write-SmithsProgress -Activity "Updating users" -Status $group.SamAccountName -Item ($i++) -Count $count

      $value = Invoke-SmithsDynamicModuleFunction -Module $module -Function "Get-Changes" -ArgumentList @{
        Group = $group
      }
      If($value -is [System.Collections.Hashtable]){
        $changes += $value
      }

    }

    $Params = @{
      "-Identity" = $group.SamAccountName
      "-Changes" = $changes
      "-ReadOnly" = $ReadOnly
      "-Credential" = $credential
      "-ObjectType" = "GROUP"
      "-Object" = $group
    }
    $success, $failure, $skip = Set-SmithsADObject @params
    $successcount += $success
    $failurecount += $failure
    $skipcount += $skip

  }
  Write-SmithsLog -Level INFO -Activity "Complete" -Message "$successcount successes, $failurecount failures, $skipcount skipped"
}

Function main {

  Import-Module -Name (Resolve-Path -Path "$PSScriptRoot/../modules/Smiths.psm1") -Force
  Import-SmithsConfig -Overrides $Settings

  Import-SmithsModule -Name "SmithsLogging.psm1"
  $script:lastrun = Start-SmithsLog -Component "AD Group Update" -LogRun:(-not $UpdateAll) -ReadOnly:$ReadOnly

  Import-SmithsModule -Name "SmithsAD.psm1"
  Import-SmithsModule -Name "SmithsDynamicModules.psm1"

  Update-SmithsADGroups

  Stop-SmithsLog
}


main
