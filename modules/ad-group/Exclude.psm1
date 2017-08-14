[CmdletBinding()]
Param()

$groupStamp = Get-SmithsConfigSetting -Component "Active Directory" -Name "Group Do Not Sync"
$groupsOU = Get-SmithsConfigSetting -Component "Active Directory" -Name "O365 Groups OU"

Function Get-Changes {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADGroup]$Group
  )

  $curVal = $Group.adminDescription
  $stamp = ($Group.DistinguishedName -notmatch $groupsOU)
  $activity = "Exclude"

  If($stamp){
    Write-SmithsLog -Level DEBUG -Identity $Group.SamAccountName -Message "Exclude, outside O365 Groups OU"  -Activity $Activity
    @{adminDescription = @{Type = "Set"; Value = $groupStamp}}
  }
  Else {
    If($curVal -match $groupStamp){
      Write-SmithsLog -Level DEBUG -Identity $Group.SamAccountName -Message "Do not exclude, in O365 Groups OU"  -Activity $Activity
      @{adminDescription = @{Type = "Set"; Value = $null}}
    }
    Else {
      Write-SmithsLog -Level DEBUG -Identity $Group.SamAccountName -Message "Do not exclude, no changes necessary."  -Activity $Activity
    }
  }
}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  @("adminDescription")

}


Function Get-Priority {

  [CmdletBinding()]
  Param()

  10

}
