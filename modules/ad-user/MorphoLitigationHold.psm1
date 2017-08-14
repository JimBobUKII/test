[CmdletBinding()]
Param()

$allLicenseGroups = [string[]](Get-SmithsConfigGroupSetting -Component Licensing | Select -ExpandProperty Include)
$holdGroup = Get-SmithsConfigSetting -Component "Active Directory" -Name "Morpho Legal Hold Group" | Get-ADGroup | Select -ExpandProperty DistinguishedName
$script:activity = "Morpho Legal Hold"

Function Get-Changes {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser]$User
  )

  $licenseCount = ($User.memberOf | Where { $allLicenseGroups -contains $_ }).Count

  If($licenseCount -gt 0){
    $dnc = Get-DNComponents -DistinguishedName $User.DistinguishedName
    If(((Compare-DNSegment -DN $dnc -Segment -5 -Value "^OU=Detection$") -or (Compare-DNSegment -DN $dnc -Segment -6 -Value "^OU=CCHQ$"))){
      Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Message "Detection or CCHQ." -Activity $script:activity
      $add = ($holdGroup -notin $User.MemberOf)
      If($add){
        Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Message "not already in hold group, adding" -Activity $script:activity
        @{MemberOf = @{Type = "Add"; Value = $holdGroup}}
      }
      Else {
        Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Message "already in hold group, skipping" -Activity $script:activity
      }
    }
  }
  Else {
    Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Message "not licensed, skipping." -Activity $script:activity
  }



}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  [string[]]@("memberOf", "adminDescription", "mail")

}

Function Get-Priority {

  [CmdletBinding()]
  Param()

  60

}
