[CmdletBinding()]
Param()

Function Get-Data {

  [CmdletBinding()]
  Param(
    [Hashtable[]]$DataSets
  )

  $btdata = Import-CSV "$Smithsroot/data/dpstatus.csv"
  $mappings = @{
    NotInstalled = "Scheduled"
    Installed = "Pending Start"
    Running = "Running (On Screen)"
  }
  Foreach($entry in $btdata){
    If($entry.DPStatus -in $mappings.Keys){
      $entry.DPStatus = $mappings[$entry.DPStatus]
    }
  }

  @{
    Filename = "bittitan-status.json"
    Data = $btdata
  }

  Try {
    $historical = [PSCustomObject[]](Import-CSV "$smithsroot/data/dphistory.csv")
  }
  Catch {
    $historical = @()
  }
  $run = @{
    Timestamp = (Get-Date -Format o)
  }
  $summary = $btdata | Group-Object DPStatus
  Foreach($entry in $summary){
    $run[$entry.Name] = $entry.Count
  }
  $historical += (New-Object PSCustomObject -Property $run)
  $historical | Export-CSV -NoTypeInformation -Path "$smithsroot/data/dphistory.csv"
  $chartData = New-Object System.Collections.ArrayList
  $cols = New-Object System.Collections.ArrayList
  $colNames = New-Object System.Collections.ArrayList
  $x = $cols.Add([PSCustomObject]@{label = "Date";type = "datetime"})
  Foreach($s in @("Pending Start", "Scheduled", "Running (On Screen)","Complete", "Failed", "Installing")){
    $x = $cols.Add([PSCustomObject]@{label = $s;type = "number"})
    $x = $colNames.Add($s)
  }
  $x = $chartData.Add($cols)
  Foreach($row in $historical){
    $chartRow = New-Object System.Collections.ArrayList
    $x = $chartRow.Add($row.Timestamp)
    Foreach($col in $colNames){
      $x = $chartRow.Add([Int]$row.$col)
    }
    $x = $chartData.Add($chartRow)
  }

  @{
    Filename = "bittitan-historical.json"
    Data = $chartData
  }

}

Function Get-Datasets {

  [CmdletBinding()]
  Param()

  [string[]]@()
}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  [string[]]@()
}

Function Get-Priority {

  50

}



