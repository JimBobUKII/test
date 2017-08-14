[CmdletBinding()]
Param()

$script:activity = "User Status"

$statuses = [string[]]@("On-Premises", "Migrated")
$smithsregions = @{Asia = "APAC"; Europe = "EMEA"; Africa = "EMEA"; "Oceania" = "APAC"; Americas = "Americas"; }
$regions = Import-Csv -Path "$smithsroot/data/country-codes.csv" | Where { -not (Test-NullOrBlank -Value $_.region) } |% { @{$_."alpha-2" = $smithsregions[$_.region] }}

Function Get-DivisionSummary {

  [CmdletBinding()]
  Param($Summary)

  $groupedSummary = $summary | Group-Object CombinedStatus, Division -NoElement
  $divisions = [string[]]($summary | Group-Object Division -NoElement | Select -Expand Name | Sort)
  $data = New-Object System.Collections.ArrayList
  $headers = [string[]](@("Region") + $statuses)
  $x = $data.Add($headers)
  Foreach($division in [string[]]$divisions){
    $r = New-Object System.Collections.ArrayList
    $x = $r.Add($division)
    Foreach($status in $statuses){
      $d = $groupedSummary | Where { $_.Values[0] -eq $status -and $_.Values[1] -eq $division }
      If(Test-NullOrBlank -Value $d){
        $v = 0
      }
      Else {
        $v = $d.Count
      }
      $x = $r.Add($v)
    }
    $x = $data.Add($r)
  }
  $data
}


Function Get-RegionSummary {

  [CmdletBinding()]
  Param($Summary)

  $groupedSummary = $summary | Group-Object CombinedStatus, @{Expression={If((Test-NullOrBlank -Value $_.Country) -or $_.Country -notin $regions.Keys){ "Unknown" } Else { $regions.($_.Country)}}} -NoElement
  $data = New-Object System.Collections.ArrayList
  $headers = [string[]](@("Region") + $statuses)
  $x = $data.Add($headers)
  Foreach($region in [string[]]@("Americas", "EMEA", "APAC", "Unknown")){
    $r = New-Object System.Collections.ArrayList
    $x = $r.Add($region)
    Foreach($status in $statuses){
      $d = $groupedSummary | Where { $_.Values[0] -eq $status -and $_.Values[1] -eq $region }
      If(Test-NullOrBlank -Value $d){
        $v = 0
      }
      Else {
        $v = $d.Count
      }
      $x = $r.Add($v)
    }
    $x = $data.Add($r)
  }
  $data
}


Function Get-HighLevelSummary {

  [CmdletBinding()]
  Param($Summary)

  $groupedSummary = $summary | Group-Object CombinedStatus, MailboxType
  $mbtypes = $summary | Group-Object MailboxType -NoElement | Select -ExpandProperty Name | Sort
  $data = New-Object System.Collections.ArrayList
  $headers = [string[]](@("Mailbox Type") + $statuses)
  $x = $data.Add($headers)
  Foreach($type in $mbtypes){
    $r = New-Object System.Collections.ArrayList
    $x = $r.Add($type)
    Foreach($status in $statuses){
      $d = $groupedSummary | Where { $_.Values[0] -eq $status -and $_.Values[1] -eq $type }
      If(Test-NullOrBlank -Value $d){
        $v = 0
      }
      Else {
        $v = $d.Count
      }
      $x = $r.Add($v)
    }
    $x = $data.Add($r)
  }
  $data
}

Function Get-Data {
  [CmdletBinding()]
  Param(
    [Hashtable[]]$DataSets
  )


  $divisioncounts = @{}
  $stagedcount = 0
  $migratedcount = 0
  $totalmailboxes = 0
  $data = @{}

  #$btdata = Get-SmithsADClientStatusData

  $summaryAttributes = [string[]]@("mail", "UserPrincipalName", "extensionAtribute4")

  $userdata = $DataSets.AD | Where { $_.extensionAttribute2 -ne $null -and $_.extensionAttribute4 -eq $null } | Get-SmithsADMigrationSummary -Attributes $summaryAttributes | Where { $_.Status -ne "No-Mailbox" }

  $nonuserdata = $DataSets.AD | Where { $_.extensionAttribute2 -ne $null -and $_.extensionAttribute4 -ne $null } | Get-SmithsADMigrationSummary -Attributes $summaryAttributes | Where { $_.Status -ne "No-Mailbox" }

  # The following segment outputs a file used by the account status lookup tool
  # It contains both user and resource mailbox data
  #
  @{
    Filename = "summary.json"
    Data = Get-HighLevelSummary -Summary ($userdata + $nonuserdata)
  }
  @{
    Filename = "division.json"
    Data = Get-DivisionSummary -Summary $userdata
  }
  @{
    Filename = "region.json"
    Data = Get-RegionSummary -Summary $userdata
  }
  @{
    Filename = "account-status.json"
    Data = $userdata + $nonuserdata
  }

}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  [string[]]@("mail","extensionAttribute2","extensionAttribute4", "division","Country")

}

Function Get-Datasets {

  [CmdletBinding()]
  Param()

  [string[]]@("AD")
}

Function Get-Priority {

  [CmdletBinding()]
  Param()

  20

}


