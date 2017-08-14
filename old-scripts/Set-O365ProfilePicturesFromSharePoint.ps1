<#
.SYNOPSIS
    Sets users pictures in AD and O365 from SharePoint.
.DESCRIPTION
    Sets users pictures in AD and O365 from SharePoint.
.NOTES
    Author: David Gee

    Version History:
    Version   Date        Author                Changes
    1.0       09/09/2016  David Gee             Initial release
#>
[CmdletBinding()]
Param(
  [ValidateSet("ReadOnly","TestGroup","All")]
  [string]$TestMode = "ReadOnly",
  [string]$CustomFilter = ""
)

Function Invoke-SQLQuery {
  [CmdletBinding()]
  Param(
    $Query,
    $ServerInstance,
    $Database,
    $Credential
  )


  $scriptblock = {
    Param(
      $Query,
      $ServerInstance,
      $Database
    )
    Invoke-SqlCmd -Query $Query -ServerInstance $ServerInstance -Database $Database
  }
  Start-Job -ScriptBlock $scriptblock -ArgumentList @($Query, $serverInstance, $Database) -Credential $Credential | Wait-Job | Receive-Job
}

Function Get-ProfilePictureData {

  [CmdletBinding()]
  Param()

  $Query = Get-SmithsConfigSetting -Component "SharePoint" -Name "Query"
  $database = Get-SmithsConfigSetting -Component "SharePoint" -Name "Database"
  $sqlserver = Get-SmithsConfigSetting -Component "SharePoint" -Name "SQL Server"
  $credential = Get-SmithsConfigSetting -Component "SharePoint" -Name "Credential"

  Invoke-SQLQuery -Query $Query -Server $sqlserver -Database $Database -Credential $Credential
}

Function Get-SharePointPhoto {

  [CmdletBinding()]
  Param(
    $PhotoUrl
  )

  $wr = Invoke-WebRequest -Uri $PhotoUrl -UseDefaultCredentials
  $wr.Content

}

Function Update-ProfilePictures {

  [CmdletBinding()]
  Param(
    [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true)]
    $ProfilePictures
  )

  Begin {
    $adCredential = Get-SmithsConfigSetting -Component "Active Directory" -Name "Credential"
    $successcount = 0
    $failurecount = 0
    $skipcount = 0
  }

  Process {

    If($ProfilePictures.username -match "^SMITHSNET\\(.*)$"){
      $lthumburl = $ProfilePictures.picurl -replace "_MThumb.jpg$", "_LThumb.jpg"
      $mthumburl = $ProfilePictures.picurl

      $o365user = "david.gee.cloud@smithsgroup.onmicrosoft.com"
      $adUsername = "jchqdgee2-la"

      # Commented out for now until AAD Connect is in place
      #$adUsername = $username
      #$adUser = Get-ADUser -Identity $adUsername
      #$o365Username = $adUser.UserPrincipalName

      $lthumb = Get-SharePointPhoto -PhotoUrl $lthumburl
      $mthumb = Get-SharePointPhoto -PhotoUrl $mthumburl
      $success, $failure, $skip = Update-ADUser -Identity $username -Changes @{thumbnailPhoto = @{Type = "Set"; Value = $mthumb}} -Credential $adCredential -TestMode All
      Set-UserPhoto -Identity $o365user -PictureData $lthumb -Confirm:$false -ErrorAction Stop
      $successcount += $success
      $failurecount += $failure
      $skipcount += $skip
#
    }
    Else {
      Write-SmithsLog -Level WARN -Message "Invalid username $($ProfilePictures.username)"
    }

  }

  End {
    Write-SmithsLog -Level INFO -Message "Completed updating profile pictures: $successcount successes, $failurecount failures, $skipcount skipped."

  }


}

Function main {

  Import-Module -Name "$PSScriptRoot/modules/Smiths.psm1" -Force
  Import-SmithsModule -Name "SmithsLogging.psm1"
  Import-SmithsModule -Name "SmithsAD.psm1"
  Import-SmithsModule -Name "SmithsExchangeOnline.psm1"

  Import-SmithsConfig
  Connect-SmithsO365
  $eosession = Connect-ExchangeOnline
  $importedsession = Import-PSSession -Session $eosession

  Get-ProfilePictureData | Update-ProfilePictures

  Disconnect-ExchangeOnline
}


main


