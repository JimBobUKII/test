[CmdletBinding()]
Param()

Function Get-Data {

  [CmdletBinding()]
  Param(
    [Hashtable[]]$DataSets
  )

  $data = New-Object System.Collections.ArrayList
  $allLicenses = Get-SmithsConfigGroupSetting -Component "Licensing"
  $allLicenseGroups = $allLicenses | Select -ExpandProperty Include
  $DataSets.AD | Where {
    $_.mail -ne "" -and
    $_.mail -ne $null -and
    $_.extensionAttribute4 -ne $null -and
    ($_.memberOf | Where { $_ -in $allLicenseGroups }).Count -gt 0
  } | Foreach-Object {
    $user = $_
    $hasLicenses = ($allLicenses | Where { ($_.Include | Where { $_ -in $user.memberOf }).Count -gt 0 } | Select -ExpandProperty Description) -join ","
    $x = $data.Add(@{
      Name = $_.Name
      Username = $_.SamAccountName
      PrimarySmtp = $_.mail
      MailboxType = $_.extensionAttribute4
      Licenses = $hasLicenses
    })
  }
  @{
    Filename = "licensed-resources.json"
    Data = $data
  }
}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  [string[]]@("extensionAttribute4", "mail", "memberOf")
}

Function Get-Datasets {

  [CmdletBinding()]
  Param()

  [string[]]@("AD")
}


Function Get-Priority {

  80

}




