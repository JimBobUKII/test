[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [ValidateScript({Test-Path $_})]
  [ValidateNotNullOrEmpty()]
  $Path,
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [PSCredential]$Credential
)

Function Get-UPNStatus {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Username

  )

  Begin {
    $domains = Get-ADForest | Select -ExpandProperty UPNSuffixes
    $domains += "smiths.net"
  }

  Process {
    $user = Get-ADUser -Identity $Username -Properties mail
    $oldUPN = $user.UserPrincipalName
    $newUPN = $null
    If($user.UserPrincipalName -match "@smiths.net$"){
      $status = "Change"
      If($user.mail -eq $null -or $user.mail -eq ""){
        $status = "No e-mail"
      }
      ElseIf($user.mail -eq $user.UserPrincipalName){
        $status = "Complete"
      }
      ElseIf($user.mail -match "@(.*)$"){
        If($matches.1 -in $domains){
          $newUPN = $user.mail
        }
        Else {
          $status = "Invalid domain"
        }
      }
    }
    Else {
      If($user.UserPrincipalName -eq $user.mail){
        $status = "Complete"
      }
      Else {
        $status = "Skip"
      }
    }
    [PSCustomObject]@{
      Username = $user.SamAccountName
      Status = $status
      OldUPN = $oldUPN
      NewUPN = $newUPN
    }
  }

  End {
  }

}

Function Update-UPN {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [PSCustomObject]$User
  )

  Begin {
  }

  Process {
    If($User.Status -eq "Change"){
      Try {
        Write-Host "Changing $($User.Username) UPN from '$($User.OldUPN)' to '$($User.NewUPN)'"
        Set-ADUser -Identity $User.Username -UserPrincipalName $User.NewUPN -Credential $Credential
      }
      Catch {
        Write-Host -ForegroundColor Red "[ERROR] $($_.Exception.Mesage)"
      }
    }
  }

  End {
  }

}

Function main {

  $users = Get-Content $Path

  $users | Get-UPNStatus | Update-UPN

}

main
