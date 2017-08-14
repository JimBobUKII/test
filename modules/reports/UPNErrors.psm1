[CmdletBinding()]
Param()

Function Get-Data {

  [CmdletBinding()]
  Param(
    [Hashtable[]]$DataSets
  )

  $data = New-Object System.Collections.ArrayList
  $DataSets.AD | Where {
    $_.UserPrincipalName -notmatch "@smiths\.net$" -and
    $_.UserPrincipalName -ne $_.mail -and
    $_.mail -ne "" -and
    $_.mail -ne $null -and
    $_.mail -notmatch "@attsmiths.com$"
  } | Foreach-Object {
    $x = $data.Add(@{
      Name = $_.Name
      Username = $_.SamAccountName
      UPN = $_.UserPrincipalName
      PrimarySmtp = $_.mail
    })
  }
  @{
    Filename = "upn-errors.json"
    Data = $data
  }
}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  [string[]]@("mail")
}

Function Get-Datasets {

  [CmdletBinding()]
  Param()

  [string[]]@("AD")
}


Function Get-Priority {

  80

}



