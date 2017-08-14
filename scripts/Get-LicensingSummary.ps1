[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  $Path
)

$groups = [string[]]@(
  "BIS O365 Exchange Online Plan 1 Users"
  "BIS O365 Exchange Online Plan 2 Users"
  "BIS O365 E1 Users"
  "BIS O365 E3 Users"
)

$ous = @{}

Function Get-DivisionFromOU {
  [CmdletBinding()]
  Param(
    $OU
  )

  $division = "Unknown"

  If($OU -ne $null)
  {
    If($OU -in $ous.Keys){
      $division = $ous[$OU]
    }
    Else {
      $orgunit = [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit[]](Get-ADOrganizationalUnit -Filter {OU -eq $OU} -SearchBase "OU=REgions,dc=smiths,dc=net")
      If($orgunit.Count -eq 1){
        $dnsplit = $orgunit[0].DistinguishedName -split "(?<!\\),"
        If($dnsplit.Count -gt 4){
          $division = $dnsplit[-5].Substring(3)
        }
      }
      $ous[$OU] = $division
    }
  }
  $division
}

Function Get-LicensedUsers {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADGroup]$LicenseGroup
  )

  $dn = $LicenseGroup.DistinguishedName
  Get-ADUser -Filter {MemberOf -eq $dn} -Properties extensionAttribute4,Division,DisplayName,PhysicalDeliveryOfficeName -SearchBase "OU=Regions,DC=Smiths,DC=Net"
}

Function Format-Users {
  [CmdletBinding()]
  Param(
    [Parameter(ValueFromPipeline=$true)]
    [Microsoft.ActiveDirectory.Management.ADUser]$User,
    [string]$License
  )

  Begin {
  }

  Process {
    $dnsplit = $User.DistinguishedName -split "(?<!\\),"
    $division = "Unknown"
    If($User.Division -eq $null){
      $division = Get-DivisionFromOU -OU $User.PhysicalDeliveryOfficeName
    }
    Else {
      $division = $User.Division
    }
    $division = $division -replace "Central","Corporate"
    $status = "Active User"
    If(-not $User.Enabled){
      $status = "Disabled User"
    }
    If($dnsplit.Count -gt 5 -and $dnsplit[-6] -eq "OU=Hold"){
      $status = "Hold"
    }
    If($User.extensionAttribute4 -match "(?<type>Room|Shared|Equipment)"){
      $status = $matches.type
      $type = $matches.type
    }
    Else {
      $type = "User"
    }
    [PSCustomObject]@{
      Username = $User.SamAccountName
      DisplayName = $User.DisplayName
      License = $License
      Division = $division
      Enabled = $User.Enabled
      Office = $User.PhysicalDeliveryOfficeName
      Status = $status
      Type = $type
    }
  }

  End {
  }
}

Function main {

  $licenseGroups = $groups | Get-ADGroup
  Remove-Item -Path $Path -ErrorAction SilentlyContinue
  Foreach($grp in $licenseGroups){
    Get-LicensedUsers -LicenseGroup $grp | Format-Users -License $grp.Name | Export-Csv -NoTypeInformation -Encoding utf8 -Path $Path -Append
  }
}

main

