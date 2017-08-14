[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$Identity
)

$user = Get-ADUser -Identity $Identity

[Convert]::ToBase64String($user.ObjectGUID.ToByteArray())

