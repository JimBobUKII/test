<#
.SYNOPSIS
    Updates profile pictures in Office 365.
.DESCRIPTION
    Monitors a folder and updates profile pictures in Office 365 when new images are found. Profile pictures should follow the naming convention <user_upn>.jpg
.NOTES
    Author: David Gee

    Version History:
    Version   Date        Author                Changes
    1.0       08/29/2016  David Gee             Initial release
#>
[CmdletBinding()]
Param()


Function main {

  Import-Module -Name "$PSScriptRoot/modules/Smiths.psm1" -Force
  Import-SmithsModule -Name "SmithsLogging.psm1"
  Import-SmithsModule -Name "SmithsExchangeOnline.psm1"

  Import-SmithsConfig

  Connect-SmithsO365
  $eolsession = Connect-ExchangeOnline
  $importedsession = Import-PSSession -Session $eolsession

  $dir = Get-SmithsConfigSetting -Component "Profile Pictures" -Name "directory"
  $dir = $dir -replace "{script}", $PSScriptRoot
  If(Test-Path -Path $dir){

    $items = Get-ChildItem -Path $dir -Filter "*.jpg"
    $successes = 0
    $failures = 0

    Foreach($item in $items){

      # Determine the UPN by removing the .JPG suffix
      $upn = $item.Name.Substring(0, $item.Name.Length-4)
      # Read the photo into memory
      $picturedata = [System.IO.File]::ReadAllBytes($item.Fullname)

      try {

        # Update the photo
        Set-UserPhoto -Identity $upn -PictureData $picturedata -Confirm:$false -ErrorAction Stop
        Write-SmithsLog -Level DEBUG -Message "Updated profile picture for $upn"
        $successes++

      }

      catch {
        $failures++
        Write-SmithsLog -Level ERROR -Message "Failed to update profile picture for ${upn}: $($_.Exception.Message)"

      }

    }

    Write-Host "Completed processing profile pictures: $successes successes, $failures failures."

  }
  Else {
    Write-SmithsLog -Level FATAL -Message "Unable to find directory '$dir'"
    exit 1
  }

  Disconnect-ExchangeOnline
}

main
