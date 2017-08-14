[CmdletBinding()]
Param(
  [string[]]$ModuleList,
  [string]$CustomFilter,
  [Hashtable]$Settings
)

Function Create-Reports {

  [CmdletBinding()]
  Param()

  $modulePath = Get-SmithsConfigSetting -Component "Reports" -Name "Modules"
  $htmlRegex = Get-SmithsConfigSetting -Component "Reports" -Name "HTML Regex"

  $modules = Import-SmithsDynamicModules -Path $modulePath -ModuleList $ModuleList

  $searchBase = Get-SmithsConfigSetting -Component "Active Directory" -Name "Search Base"
  $attributes = Invoke-SmithsDynamicModuleFunctionForAll -Function "Get-Attributes"
  $dataSets = Invoke-SmithsDynamicModuleFunctionForAll -Function "Get-DataSets" | Select -Unique

  $ds = @{}
  If($dataSets -Contains "AD"){
    Write-SmithsLog -Level INFO -Activity "Getting User Data" -Message "Finding AD users"

    $ldapFilter = Get-SmithsADLDAPFilter -ObjectType "USER" -UpdateAll -CustomFilter $CustomFilter
    $userArgs = @{
      "-LDAPFilter" = $ldapFilter
      "-SearchBase" = $searchbase
    }
    If($attributes -ne $null -and $attributes.Count -gt 0){
      $userArgs."-Properties" = $attributes
    }
    $ds.AD = [Object[]](Get-ADUser @userArgs)
    Write-SmithsLog -Level INFO -Activity "Getting User Data" -Message "$($ds.AD.Count) AD users found"
  }
  If($dataSets -Contains "O365"){
    Import-SmithsModule -Name "SmithsO365.psm1"
    Connect-SmithsO365

    Write-SmithsLog -Level INFO -Activity "Getting User Data" -Message "Finding Office 365 users"
    $ds.O365 = Get-MsolUser -Synchronized -All
    Write-SmithsLog -Level INFO -Activity "Getting User Data" -Message "$($ds.O365.Count) Office 365 users found"
  }
  If($dataSets -Contains "ExchangeOnline"){
    Import-SmithsModule -Name "SmithsExchangeOnline.psm1"
    Connect-ExchangeOnline

    Write-SmithsLog -Level INFO -Activity "Getting User Data" -Message "Finding Exchange Online mailboxes"
    $ds.ExchangeOnline = Get-Mailbox -ResultSize Unlimited
    Write-SmithsLog -Level INFO -Activity "Getting User Data" -Message "$($ds.ExchangeOnline.Count) Exchange Online mailboxes"
  }

  $dataDir = Get-SmithsConfigSetting -Component "Reports" -Name "Data Directory"
  Try {
    New-Item -Path $dataDir -Type Directory -ErrorAction SilentlyContinue
  }
  Catch {
  }

  Foreach($module in $modules){

    $data = [Hashtable[]](Invoke-SmithsDynamicModuleFunction -Module $module -Function "Get-Data" -ArgumentList @{DataSets = $ds})
    Foreach($d in $data){
      If(Test-NullOrBlank -Value $d.Filename){
        Write-SmithsLog -Level ERROR -Activity "Save Reports" -Message "No filename for data"
        Write-SmithsLog -Level ERROR -Activity "Save Reports" -Message ($d | ConvertTo-Json)
      }
      $filename = $d.Filename
      @{data = $d.Data} | ConvertTo-Json -Depth 5 | Out-File "$SmithsRoot\$dataDir\$filename" -Encoding utf8
    }

  }

  [PSCustomObject]@{LastUpdated = (Get-Date -Format o)} | ConvertTo-Json | Out-File "$SmithsRoot\$dataDir\last-updated.json" -Encoding utf8

}


Function main {

  Import-Module -Name (Resolve-Path -Path "$PSScriptRoot/../modules/Smiths.psm1") -Force
  Import-SmithsConfig -Overrides $Settings

  Import-SmithsModule -Name "SmithsLogging.psm1"
  Start-SmithsLog -Component "Create Reports" -LogRun:$false -ReadOnly:$false

  Import-SmithsModule -Name "SmithsAD.psm1"
  Import-SmithsModule -Name "SmithsDynamicModules.psm1"

  Create-Reports

  Stop-SmithsLog
}


main



