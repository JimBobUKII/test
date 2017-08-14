[CmdletBinding()]
Param(
  [switch]$ReadOnly,
  [Parameter(Mandatory=$True)]
  [ValidateScript({Test-Path $_})]
  [ValidateNotNullOrEmpty()]
  [string]$Userfile,
  [Hashtable]$Settings
)

Function Update-SmithsActiveSyncSettings {

  $successcount = 0
  $failurecount = 0
  $skipcount = 0

  $users = Import-CSV -Path $Userfile

  Write-SmithsLog -Level DEBUG -Activity "Processing Users" -Message "Starting processing"
  $activeSyncSettings = Get-SmithsConfigGroupSetting -Component "Legacy ActiveSync"
  $newActiveSyncGroup = (Get-SmithsConfigGroupSetting -Component "Mailbox Features" | Where { $_.Name -eq "ActiveSyncEnabled" }).Include[0]
  $credential = Get-SmithsConfigSetting -Component "Active Directory" -Name "Credential"

  If($users[0].samaccountname -ne $null){
    $usernamefield = "samaccountname"
  }
  ElseIf($users[0].username -ne $null){
    $usernamefield = "username"
  }
  Else {
    Write-SmithsLog -Level FATAL -Activity "Updating users" -Message "No username field found, aborting"
    Exit 1
  }


  $i = 0
  $count = $users.Count
  Foreach($user in $users){

    [Hashtable]$changes = @{}
    $adUser = Get-ADUser -Identity $user.$usernamefield -Properties memberOf
    Write-SmithsProgress -Activity "Updating users" -Status $adUser.SamAccountName -Item ($i++) -Count $count

    [string[]]$mdmGroups = $activeSyncSettings | Test-SmithsGroupMemberships -MemberOf $adUser.memberOf | Select -ExpandProperty Include
    If($mdmGroups.Count -gt 0){
      Write-SmithsLog -Level DEBUG -Activity "Analyzing group memberships" -Identity $adUser.SamAccountName -Message "User is in legacy MDM group(s) $($mdmGroups -join ", ")"
      Try {
        Foreach($grp in $mdmGroups){
          Write-SmithsLog -Level DEBUG -Activity "Changing group membership" -Message "Removing from $grp" -Identity $adUser.SamAccountName
          If(-not $ReadOnly){
            Remove-ADGroupMember -Identity $grp -Members $adUser.SamAccountName -Credential $credential -Confirm:$false
          }
        }
        Write-SmithsLog -Level DEBUG -Activity "Changing group membership" -Message "Adding to $newActiveSyncGroup" -Identity $adUser.SamAccountName
        If(-not $ReadOnly){
          Add-ADGroupMember -Identity $newActiveSyncGroup -Members $adUser.SamAccountName -Credential $credential
          $successcount++
        }
        Else {
          $skipcount++
        }
      }
      Catch {
        Write-SmithsLog -Level ERROR -Activity "Changing group memberships" -Identity $adUser.SamAccountName -Message $_.Exception.Message
        $failurecount++
      }

    }
    Else {
      $skipcount++
      Write-SmithsLog -Level DEBUG -Activity "Analyzing group memberships" -Identity $adUser.SamAccountName -Message "User not in ActiveSync group, skipping"
    }

  }
  Write-SmithsLog -Level INFO -Activity "Complete" -Message "$successcount successes, $failurecount failures, $skipcount skipped"
}

Function main {

  Import-Module -Name (Resolve-Path -Path "$PSScriptRoot/../modules/Smiths.psm1") -Force
  Import-SmithsConfig -Overrides $Settings

  Import-SmithsModule -Name "SmithsLogging.psm1"
  $script:lastrun = Start-SmithsLog -Component "Migration Group Update" -LogRun:(-not $UpdateAll) -ReadOnly:$ReadOnly

  Update-SmithsActiveSyncSettings

  Stop-SmithsLog
}


main


