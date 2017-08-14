[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [ValidateScript({Test-Path $_})]
  [string]$Path,
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$NewVersion
)

Function Test-IsAdmin {

  ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

}

Function main {

  Push-Location $container
  Set-Location (Get-Item $Path).FullName
  Start-Process "cmd.exe" -ArgumentList @("/C", "rmdir", "PREVIOUS") -NoNewWindow
  Start-Process "cmd.exe" -ArgumentList @("/C", "rename", "LATEST", "PREVIOUS") -NoNewWindow
  Start-Process "cmd.exe" -ArgumentList @("/C", "mklink", "/d", "LATEST", $NewVersion) -NoNewWindow
  Start-Sleep 5
}

If(-not (Test-IsAdmin)){

  $script = Get-PSCallStack | Where { $_.ScriptName -ne $null } | Select -Last 1 -ExpandProperty ScriptName

  Start-Process "powershell" -ArgumentList @("-File", $script, "-NewVersion", $NewVersion, "-Path", (Get-Item $Path).FullName) -Verb RunAs
}

Else {

  main

}
