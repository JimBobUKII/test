[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true,ParameterSetName="OU")]
  [ValidateNotNullOrEmpty()]
  $OU,
  [Parameter(Mandatory=$true,ParameterSetName="File")]
  [ValidateNotNullOrEmpty()]
  [ValidateScript({Test-Path $_})]
  $Path
)

Function Get-Perms {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $User
  )

  Begin {
  }

  Process {
    $perms = [string[]](Get-MailboxPermission $User.UserPrincipalName | Where { $_.User -notmatch "^(NT AUTHORITY|NAMPR|S-1-5|PRDT)" } | Select -ExpandProperty User)
    If($perms.Count -eq 0){
      "NONE"
    }
    Else {
      $perms -join ", "
    }
  }

  End {
  }

}

Function main {
  $licenses = @(
    "BIS O365 Exchange Online Plan 1 Users"
    "BIS O365 Exchange Online Plan 2 Users"
    "BIS O365 E1 Users"
    "BIS O365 E3 Users"
  )

  Switch($PSCmdlet.ParameterSetName){
    "OU" {
      If($OU -match "^OU="){
        $ouPath = @(Get-ADOrganizationalUnit $OU)
      }
      Else {
        $ouPath = [Microsoft.ActiveDirectory.Management.ADOrganizationalUnit[]](Get-ADOrganizationalUnit -Filter {OU -eq $OU})
      }
      If($ouPath.Count -ne 1){
        throw "$($ouPath.Count) OUs found (need exactly 1), aborting"
      }
    


      $i = 1
      Foreach($license in $licenses){


        $licenseDN = (Get-ADGroup $license).DistinguishedName
        $adusers = [Microsoft.ActiveDirectory.Management.ADUser[]](Get-ADUser -SearchBase $ouPath[0].DistinguishedName -Filter {Enabled -eq $false -and MemberOf -eq $licenseDN} -Properties mail,lastLogonDate)

        $j = 0
        Foreach($aduser in $adusers){
          Write-Progress -Activity $license -Status "$($aduser.Name) ($j / $($adusers.Count))" -PercentComplete (25 * $i * ($j++ / $adusers.Count))
          $perms = $aduser | Get-Perms
          [PSCustomObject]@{
            User = $aduser.SamAccountName
            License = $license
            Permissions = $perms
            ADLastLogon = $aduser.LastLogonDate
          }
        }
        $i++
      }

    }
    "File" {
      $i = 1
      $userdata = Get-Content $Path
      Foreach($user in $userdata){
        Foreach($license in $licenses){
          $licenseDN = (Get-ADGroup $license).DistinguishedName
          $aduser = Get-ADUser -Filter {SamAccountName -eq $user -and MemberOf -eq $licenseDN} -Properties mail,lastLogonDate
          If($aduser -ne $null){
            Write-Progress -Activity $license -Status "$($aduser.Name) ($i / $($userdata.Count))" -PercentComplete (100 * $i / $userdata.count)
            $perms = $aduser | Get-Perms
            [PSCustomObject]@{
              User = $user
              License = $license
              Permissions = $perms
              ADLastLogon = $aduser.LastLogonDate
            }
          }
        }
        $i++
      }
    }
  }

}

main
