[CmdletBinding()]
Param(
)


$ascii=$NULL;For ($a=33;$a -le 126;$a++) {$ascii+=,[char][byte]$a }

Function Get-RandomPassword() {

  [CmdletBinding()]
  Param()

  $Temppassword = ""

  For($loop=1; $loop -le 16; $loop++) {
    $TempPassword += ($ascii| Get-Random)
  }

  $TempPassword

}

Get-RandomPassword
