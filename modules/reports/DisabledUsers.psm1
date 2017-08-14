[CmdletBinding()]
Param()

Function Get-Data {

  [CmdletBinding()]
  Param(
    [Hashtable[]]$DataSets
  )

  $i = 0
  $users = $DataSets.AD

  $licenses = Get-SmithsConfigGroupSetting -Component Licensing
  $allLicenseGroups = $licenses | Select -ExpandProperty Include

  $disabledLicensedUsers = $users | Where { (-not $_.Enabled) -and $_.extensionAttribute4 -eq $null -and ($_.memberOf | Where { $_ -in $allLicenseGroups }).Count -gt 0 }

  $disabledData = New-Object System.Collections.ArrayList
  Foreach($user in $disabledLicensedUsers){
    $hasLicenses = ($licenses | Where { ($_.Include | Where { $_ -in $user.memberOf }).Count -gt 0 } | Select -ExpandProperty Description) -join ","
    $x = $disabledData.Add(@{
      Name = $User.Name
      Username = $user.SamAccountName
      EmailAddress = $user.mail
      UPN = $user.UserPrincipalName
      Licenses = $hasLicenses
    })
  } # end foreach

  @{
    Filename = "disabled-licenses.json"
    Data = $disabledData
  }
}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  [string[]]@("memberOf", "mail", "extensionAttribute4")
}

Function Get-Datasets {

  [CmdletBinding()]
  Param()

  [string[]]@("AD")
}

Function Get-Priority {

  40

}


