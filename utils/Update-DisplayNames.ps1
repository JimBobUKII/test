[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [ValidateScript({Test-Path "displaynames/${_}.csv"})]
  $SiteCode,
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [PSCredential]$Credential,
  [switch]$ReadOnly,
  [switch]$Override
)

Function main {

  $data = Import-CSV "displaynames/$SiteCode.csv"

  Foreach($d in $data){
    If($d.DisplayName -eq $d.NewDisplayName -and $d.extensionattribute4 -eq $d.newea4){
      Write-Host "No change to display name for $($d.samaccountname) in file, skipping"
    }
    Else {
      $u = Get-ADUser $d.samaccountname -Properties displayname
      If($u.displayname -eq $d.displayname -or $Override){
        If($Override -and $u.displayname -eq $d.displayname){
          Write-Host "DisplayName of $($d.samaccountname) has changed and override is set"
        }

        # OK, no change, so we can update it
        Write-Host "Updating $($d.samaccountname)"
        If(-not $ReadOnly){
          $props = @{
            "-DisplayName" = $d.NewDisplayName
            "-Credential" = $credential
          }
          If($d.newea4 -ne ""){
            $props."-replace" = @{extensionAttribute4 = $d.newea4}
          }
          Else {
            $props."-clear" = "extensionattribute4"
          }
          $u | Set-ADUser @props #-Displayname $d.NewDisplayName -replace @{extensionAttribute4=$d.newea4} -Credential $Credential
        }
      }
      Else {
        Write-Host "DisplayName of $($d.samaccountname) has changed, skipping"
      }
    }
  }

}

main
