[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)]
  [ValidateScript({Test-Path $_})]
  [ValidateNotNullOrEmpty()]
  [string]$Userfile,
  [Parameter(Mandatory=$True)]
  [ValidateNotNullOrEmpty()]
  [ValidateSet("Licensing", "Mailbox Features", "Retention Policies", "Migration")]
  [string]$GroupType,
  [switch]$ReadOnly,
  [Hashtable]$Settings
)

Function Add-Users {

  [CmdletBinding()]
  Param()

  $users = Import-CSV $Userfile
  $settings = Get-SmithsConfigGroupSetting -Component $GroupType
  $credential = Get-SmithsConfigSetting -Component "Active Directory" -Name "Credential"

  # Store all the changes and do them at the end
  $groupAdds = @{}
  $groupRemoves = @{}

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

  $eo1group = "CN=BIS O365 Exchange Online Plan 1 Users,OU=Office 365,OU=Global Groups,OU=Global,OU=Regions,DC=smiths,DC=net"
  Foreach($user in $users){

    $setting = $settings | Where { $_.Name -eq $user.setting }
    $grp = $setting.Include[0]
    If($setting -eq $null){
      Write-SmithsLog -Level ERROR -Identity $user.$usernamefield -Message "Invalid entry '$($user.setting)'" -Activity "Prepare Update"
    }
    Else {
      Try {
        $adUser = Get-ADUser -Identity $user.$usernamefield -ErrorAction Stop -Properties memberOf
        $removefromGroup = $null
        $isInGroup = (($adUser.MemberOf | Where { $_ -match $grp }).Count -gt 0)
        If($isInGroup){
          Write-SmithsLog -Level DEBUG -Identity $user.$usernamefield -Message "already in group '$grp', skipping" -Activity "Prepare Update"
        }
        Else {
          If($groupAdds.ContainsKey($grp)){
            $groupAdds[$grp] += $user.$usernamefield
          }
          Else {
            $groupAdds[$grp] = @($user.$usernamefield)
          }
          If($GroupType -eq "Licensing" -and $user.setting -eq "EXCHANGEENTERPRISE" -and $eo1group -in $adUser.memberOf){
            If($groupRemoves.ContainsKey($eo1group)){
              $groupRemoves[$eo1group] += $user.$usernamefield
            }
            Else {
              $groupRemoves[$eo1group] = @($user.$usernamefield)
            }
          }
        }
      }
      Catch {
        Write-SmithsLog -Level ERROR -Identity $user.$usernamefield -Message "user not found in AD" -Activity "Prepare Update"
      }
    }

  }

  Foreach($group in $groupAdds.GetEnumerator()){

    $groupname = $group.Name
    $users = $group.Value

    Try {
      Write-SmithsLog -Level INFO -Identity $groupname -Message "Adding $($users.Count) users to group" -Activity "Update Group"
      If(-not $ReadOnly){
        Add-ADGroupMember -Identity $groupname -Members $users -Credential $credential
      }
    }
    Catch {
      Write-SmithsLog -Level ERROR -Identity $groupname -Message "Error adding users: $($_.Exception.Message)"  -Activity "Update Group"
    }

  }

  Foreach($group in $groupRemoves.GetEnumerator()){

    $groupname = $group.Name
    $users = $group.Value

    Try {
      Write-SmithsLog -Level INFO -Identity $groupname -Message "Removing $($users.Count) users from group" -Activity "Update Group"
      If(-not $ReadOnly){
        Remove-ADGroupMember -Identity $groupname -Members $users -Credential $credential
      }
    }
    Catch {
      Write-SmithsLog -Level ERROR -Identity $groupname -Message "Error removing users: $($_.Exception.Message)"  -Activity "Update Group"
    }

  }

}

Function main {

  Import-Module -Name (Resolve-Path -Path "$PSScriptRoot/../modules/Smiths.psm1") -Force
  Import-SmithsModule -Name "SmithsLogging.psm1"
  $script:lastrun = Start-SmithsLog -Component "Migration Group Update" -LogRun:(-not $UpdateAll) -ReadOnly:$ReadOnly

  Import-SmithsConfig -Overrides $Settings

  Add-Users

  Stop-SmithsLog

}


main

