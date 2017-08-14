[CmdletBinding()]
Param(
  [ValidateNotNullOrEmpty()]
  [Parameter(Mandatory=$true)]
  $CredentialFilename
)

$cred = Get-Credential
$pw = $cred.Password | ConvertFrom-SecureString
$un = $cred.UserName

"$un,$pw" | Out-File "$CredentialFilename"
