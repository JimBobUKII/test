[CmdletBinding()]
Param()

Function Get-Data {

  [CmdletBinding()]
  Param(
    [Hashtable[]]$DataSets
  )

  $skus = Get-MsolAccountSku

  $licenses = Get-SmithsConfigGroupSetting -Component Licensing
  $licenseData = New-Object System.Collections.ArrayList
  Foreach($license in $licenses){
    $assigned = 0

    # Add up all the licensed users

    Foreach($grp in $license.Include){
      $assigned += (Get-ADGroup $grp -Properties member).member.Count
    }

    # Find the number of active licenses

    $sku = $skus | Where { $_.SkuPartNumber -eq $license.Name }
    $x = $licenseData.Add(@{
      License = $license.Description
      Assigned = $assigned
      Active = $sku.ActiveUnits
      Consumed = $sku.ConsumedUnits
      Available = ($sku.ActiveUnits - $sku.ConsumedUnits)
    })
  }
  @{
    Filename = "licenses.json"
    Data = $licenseData
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

  10

}
