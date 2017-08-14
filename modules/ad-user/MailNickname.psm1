[CmdletBinding()]
Param()

$script:activity = "Mail Nickname"

Function Get-Changes {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser]$User
  )

  Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Message "Setting mailNickname = '$($User.SamAccountName)'" -Activity $script:activity
  @{mailNickname = @{Type = "Set"; Value = $User.SamAccountName}}
}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  @("mailNickname")

}



Function Get-Priority {

  [CmdletBinding()]
  Param()

  50

}
