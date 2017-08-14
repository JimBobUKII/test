[CmdletBinding()]
Param(
  [switch]$ReadOnly,
  [switch]$TestUsers,
  [string]$CustomFilter = "",
  [switch]$UpdateAll,
  [string[]]$ModuleList,
  [Hashtable]$Settings
)

Function Update-SmithsADUsers {

  $successcount = 0
  $failurecount = 0
  $skipcount = 0

  $searchbase = Get-SmithsConfigSetting -Component "Active Directory" -Name "Search Base"
  $credential = Get-SmithsConfigSetting -Component "Active Directory" -Name "Credential"
  $modulePath = Get-SmithsConfigSetting -Component "Active Directory" -Name "User Modules"

  # Returns a sorted list in priority order
  $modules = Import-SmithsDynamicModules -Path $modulePath -ModuleList $ModuleList
  $attributesToLoad = $modules | Invoke-SmithsDynamicModuleFunction -Function "Get-Attributes" | Select -Unique

  $ldapFilter = Get-SmithsADLDAPFilter -ObjectType "USER" -TestUsers:$TestUsers -UpdateAll:$UpdateAll -CustomFilter:$CustomFilter -LastRun $script:lastrun
  Write-SmithsLog -Level DEBUG -Activity "AD Search" -Message "Starting AD search"

  $users = Get-ADUser -LDAPFilter $ldapFilter -Properties $attributesToLoad -SearchBase $searchbase
  If($users -is [Microsoft.ActiveDirectory.Management.ADAccount]){
    $count = 1
  }
  Else {
    $count = $users.Count
  }

  Write-SmithsLog -Level INFO -Activity "AD Search" -Message "$count users found"

  $i = 0
  Foreach($user in $users){

    Write-SmithsProgress -Activity "Updating users" -Status $user.SamAccountName -Item ($i++) -Count $count

    $changes = @{}

    Foreach($module in $modules){

      $value = Invoke-SmithsDynamicModuleFunction -Module $module -Function "Get-Changes" -ArgumentList @{
        User = $user
      }
      If($value -is [System.Collections.Hashtable]){
        $changes += $value
      }

    }

    $Params = @{
      "-Identity" = $user.SamAccountName
      "-Changes" = $changes
      "-ReadOnly" = $ReadOnly
      "-Credential" = $credential
      "-ObjectType" = "USER"
      "-Object" = $user
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
  $script:lastrun = Start-SmithsLog -Component "AD User Update" -LogRun:(-not $UpdateAll -and -not $ReadOnly) -ReadOnly:$ReadOnly

  Import-SmithsModule -Name "SmithsAD.psm1"
  #Import-SmithsModule -Name "SmithsO365.psm1"
  Import-SmithsModule -Name "SmithsAzureAD.psm1"
  Import-SmithsModule -Name "SmithsDynamicModules.psm1"

  #Connect-SmithsO365
  Connect-SmithsAAD
  Update-SmithsADUsers

  Stop-SmithsLog
}


main

