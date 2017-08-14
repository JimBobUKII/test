[CmdletBinding()]
Param($Domain)

Function main {

  $msolUsers = Get-MsolUser -All -Synchronized -DomainName $Domain
  $msolUsers|% {
    $smithsnetUN = $_.UserPrincipalName -replace "@attsmiths.com",""
    Try {
      $u = Get-ADUser $smithsnetUN -ErrorAction Stop
      [PSCustomObject]@{
        CloudUPN = $_.UserPrincipalName
        CloudAnchor = $_.ImmutableID
        SmithsnetUPN = $u.UserPrincipalName
        SmithsnetUsername = $u.SamAccountName
        SmithsnetAnchor = [Convert]::ToBase64String($u.ObjectGuid.ToByteArray())
      }
    }
    Catch {
    }
  }

}

main
