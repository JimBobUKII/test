[CmdletBinding()]
Param()

Function Get-Data {

  [CmdletBinding()]
  Param(
    [Hashtable[]]$DataSets
  )

  $cutoff = (Get-Date).AddHours(-24)
  @{
    Filename = "licensing-errors.json"
    Data = Get-SmithsLogEntries -Cutoff $cutoff -Pattern "\[(ERROR|WARN)\].*\[LICENSING\]"
  }
  @{
    Filename = "ad-errors.json"
    Data = Get-SmithsLogEntries -Cutoff $cutoff -Pattern "\[(ERROR|WARN)\].*\[UPN UPDATE\]"
  }
  @{
    Filename = "errors.json"
    Data = Get-SmithsLogEntries -Cutoff $cutoff -Pattern "\[(ERROR|WARN)\]"
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



