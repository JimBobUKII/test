[CmdletBinding()]
Param()

$script:activity = "UserPrincipalName"

Function Get-Changes {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser]$User
  )

  Update-SmithsAADUserPrincipalName -User $User
}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  @("adminDescription")

}



Function Get-Priority {

  [CmdletBinding()]
  Param()

  100

}

