[CmdletBinding()]
Param()

$script:activity = "Licensing Detail"

$licenses = Get-SmithsConfigGroupSetting -Component "Licensing"

Function Get-Data {
  [CmdletBinding()]
  Param(
    [Hashtable[]]$DataSets
  )

  $divisionGroupingExpression = @{Expression={If((Test-NullOrBlank -Value $_.extensionAttribute2)){ "Unknown" } Else { ($_.extensionAttribute2 -split "/")[0]}}}

  $divisions = [string[]]($DataSets.AD | Group-Object $divisionGroupingExpression -NoElement | Select -ExpandProperty Name | Sort)
  $divisions | Write-Host

  $data = New-Object System.Collections.ArrayList
  $headers = New-Object System.Collections.ArrayList
  $x = $headers.Add("License")
  Foreach($division in $divisions){
    $x = $headers.Add($division)
  }
  $x = $data.Add($headers)

  Foreach($license in $licenses){

    $row = New-Object System.Collections.ArrayList
    $x = $row.Add($license.Description)

    $groups = [string[]]($license | Select -ExpandProperty Include | Get-ADGroup | Select -ExpandProperty DistinguishedName)

    $usersWithLicense = $DataSets.AD | Where { ($_.memberOf | Where { $_ -in $groups }).Count -gt 0 } | Group-Object $divisionGroupingExpression -NoElement

    Foreach($division in $divisions){
      $d = $usersWithLicense | Where { $_.Name -eq $division }
      If(Test-NullOrBlank -Value $d){
        $count = 0
      }
      Else {
        $count = $d.Count
      }
      $x = $row.Add($count)
    }
    $x = $data.Add($row)

  }




  # The following segment outputs a file used by the account status lookup tool
  # It contains both user and resource mailbox data
  #
  @{
    Filename = "licensing-detail.json"
    Data = $data
  }

}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  [string[]]@("division", "memberOf", "extensionAttribute2")

}

Function Get-Datasets {

  [CmdletBinding()]
  Param()

  [string[]]@("AD")
}

Function Get-Priority {

  [CmdletBinding()]
  Param()

  100

}



