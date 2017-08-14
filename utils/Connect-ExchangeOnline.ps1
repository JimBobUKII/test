[CmdletBinding()]
Param(
  [Hashtable]$Settings,
  [Switch]$ProxyRPS
)

Function main {

  Import-Module -Name (Resolve-Path -Path "$PSScriptRoot/../modules/Smiths.psm1") -Force
  Import-SmithsConfig -Overrides $Settings

  Import-SmithsModule -Name "SmithsLogging.psm1"
  Start-SmithsLog -Component "Connect to Exchange Online PowerShell" -LogRun:$false -ReadOnly:$ReadOnly

  Import-SmithsModule -Name "SmithsExchangeOnline.psm1"

  Connect-ExchangeOnline -ProxyRPS:$ProxyRPS

  Stop-SmithsLog
}


main


