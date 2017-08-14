[CmdletBinding()]
Param()

Function Get-Reason {

  [CmdletBinding()]
  Param(
    [Microsoft.ActiveDirectory.Management.ADUser]$User
  )
  $reasons = New-Object System.Collections.ArrayList
  If($User.c -eq $null){
    $x = $reasons.Add("No country specified")
  }
  If($User.SamAccountName -match "[^\x00-\x7F]"){
    $x = $reasons.Add("Username contains non-ASCII characters")
  }
  If($User.UserPrincipalName -match "[^\x00-\x7F]"){
    $x = $reasons.Add("UserPrincipalName contains non-ASCII characters")
  }
  If($User.UserPrincipalName -eq $null){
    $x = $reasons.Add("UserPrincipalName is blank")
  }

  $reasons -join ", "

}

$script:activity = "Azure AD Sync Errors"

Function Get-Data {
  [CmdletBinding()]
  Param(
    [Hashtable[]]$DataSets
  )

  Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "Assembling UPN list"
  $upns = [string[]]($DataSets.O365 | Select -ExpandProperty UserPrincipalName)
  Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "Finding list of AD users without corresponding UPN"
  $syncerrors = $DataSets.AD | Where { $_.adminDescription -notmatch "^User_DoNotSyncO365" -and $_.UserPrincipalName -notin $upns -and ($_.Enabled -or $_.extensionAttribute4 -in @("Room", "Equipment", "Shared")) } | Select SamAccountName,UserPrincipalName,@{label="Reason";expression={Get-Reason -User $_}}
  Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "$($syncerrors.Count) AD users found with sync errors"
  @{
    Filename = "azure-ad-sync-errors.json"
    Data = $syncerrors
  }

}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  [string[]]@("adminDescription","c", "extensionAttribute4")

}

Function Get-Datasets {

  [CmdletBinding()]
  Param()

  [string[]]@("AD", "O365")
}

Function Get-Priority {

  [CmdletBinding()]
  Param()

  20

}



