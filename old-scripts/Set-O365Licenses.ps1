<#
.SYNOPSIS
    Automatically assigns and removes O365 licenses based on Azure AD group membership.
.DESCRIPTION
    Based on a list of groups and licenses in the accompanying XML configuration file, user licenses are assigned or removed as needed. Also handles changes in license type.

    Does not remove licenses when users are disabled, in order to allow conversion to shared mailbox or inactive mailbox with legal hold.
.NOTES
    Author: David Gee, based on a script by Johan Dahlbom (see 365lab.net)

    Version History:
    Version   Date        Author                Changes
    1.0       08/29/2016  David Gee             Initial release
.PARAMETER Credential
  Specifies a credential to use when connecting to Office 365. If omitted, the user receives an interactive prompt for the credential.
#>
[CmdletBinding()]
Param(
  [switch]$ReadOnly
)

If($ReadOnly){
  $updateType = "[O365 UPDATE SIMULATION]"
}
Else {
  $updateTYpe = "[O365 UPDATE]"
}

Function main {
  Import-Module -Name (Join-Path $PSScriptRoot "O365.psm1") -Force
  Import-Module -Name (Join-Path $PSScriptRoot "O365Logging.psm1") -Force
  Import-SmithsConfig
  Connect-SmithsO365
  $script:countries = Import-O365CountryData
  $licenses = Get-SmithsConfigGroupSetting -Component Licensing
  Set-O365Licenses -Licenses $licenses
}

Function Set-O365Licenses {

  [CmdletBinding()]
  Param(
    [Object[]]$Licenses
  )

  # Get all licensed users
  $script:allLicensedUsers = Get-LicensedUsers

  # For each license that we're interested in
  Foreach($license in $licenses){

    # Get the SKU object; this is needed to determine how many licenses are available
    $sku = Get-LicenseDetails -License $license.Name
    #$sku = Get-MsolAccountSku | Where { $_.SkuPartNumber -eq $license.Name }

    If($sku -ne $null){
      # Get all the users in the group associated to this license - i.e. those who should have this license.
      #$groupUsers = Get-MsolGroupMember -GroupObjectId $license.GroupId | Select -ExpandProperty ObjectId
      $groupUsers = Get-O365GroupMembers -GroupId $license.GroupId | Select -ExpandProperty ObjectId

      # Get all the users who are currently assigned this license
      $usersWithLicense = $allLicensedUsers | Where { $_.SkuId -eq $sku.AccountSkuId } | Select -ExpandProperty UserId

      # Users that are in the first list but not the second should have the license but do not
      $usersToAdd = $groupUsers | Where { $_ -notin $usersWithLicense }

      # Users that are in the second list but not the second should not have the license but do
      $usersToRemove = $usersWithLicense | Where { $_ -notin $groupUsers }

      # Process the removals first
      Remove-Licenses -usersToRemove $usersToRemove -license $license

      Add-Licenses -usersToAdd $usersToAdd -license $license

      # Everyone else remains unchanged

    }

  }

}

Function Get-LicenseDetails {

  [CmdletBinding()]
  Param(
    $license
  )

  $msolsku = Get-MsolAccountSku | Where { $_.SkuPartNumber -eq $license }
  If($msolsku -eq $null){
    [PSCustomObject]@{
      AccountSkuId = $null
      License = $license
      Active = 0
      Used = 0
      Available = 0
    }
    Write-SmithsLog -Level DEBUG "$updateType [$license]: 0 Active, 0 Used, 0 Available"
  }
  Else {
    [PSCustomObject]@{
      AccountSkuId = $msolSku.AccountSkuId
      License = $license
      Active = $msolSku.ActiveUnits
      Used = $msolSku.ConsumedUnits
      Available = ($msolSku.ActiveUnits - $msolSku.ConsumedUnits)
    }
    Write-SmithsLog -Level DEBUG "$updateType [$license]: $($msolSku.ActiveUnits) Active, $($msolSku.ConsumedUnits) Used, $($msolSku.ActiveUnits - $msolSku.ConsumedUnits) Available"
  }

}



Function Add-Licenses {

  [CmdletBinding()]
  Param(
    $usersToAdd,
    $license
  )

  $sku = Get-LicenseDetails -license $license.Name
  $licenseName = $license.Name

  If($usersToAdd.Count -gt $sku.Available){
    Write-Error "Not enough $($license.Name) licenses: need $($usersToAdd.Count), have $($sku.Available)"
  }
  Else {
    # For each user who needs licensing
    $successCount = 0
    $errorCount = 0
    $skipCount = 0
    Foreach($user in $usersToAdd){

      Try {

        # Get the user by ID
        $msolUser = Get-MsolUser -ObjectId $user
        $upn = $msolUser.UserPrincipalName

        $country = $countries | Where { $_."Common Name" -eq $msolUser.Country }
        $countryName = $country."Common Name"
        $usageLocation = $country."ISO 3166-1 2 Letter Code"
        If($country -ne $null){
          # Update the user's usage location with the 2-digit country code
          Write-SmithsLog -Level DEBUG -Message "$updateType [$licenseName] [$upn]: Set UsageLocation = $countryName ($usageLocation)"
          If(-not $ReadOnly){
            Set-MsolUser -ObjectId $msolUser.ObjectId -UsageLocation $usageLocation
          }
        }
        Else {
          Write-SmithsLog -Level ERROR -Message "$updateType [$licenseName] [$upn]: Invalid country '$country'"
        }

        # Assign the license to the user
        Write-SmithsLog -Level DEBUG -Message "$updateType [$licenseName] [$upn]: Licensing"
        If(-not $ReadOnly){
          Set-MsolUserLicense -ObjectId $msolUser.ObjectId -AddLicenses $sku.AccountSkuId
          $successCount++
        }
        Else {
          $skipCount++
        }

      }
      Catch {

        # If we end up here, something either went wrong updating the usage location or assigning the license
        Write-SmithsLog -Level ERROR -Message "[O365 UPDATE ERROR] [$licenseName] [$upn]: Error $($_.Exception.Message)"
        $errorCount++


      }

    }
    If($usersToAdd.Count -eq 0){
      Write-SmithsLog -Level INFO -Message "$updateType [$licenseName] [COMPLETED]: No users to license"
    }
    Else {
      Write-SmithsLog -Level INFO -Message "$updateType [$licenseName] [COMPLETED]: $successcount successes, $errorCount failures, $skipCount skipped"
    }
  }



}

Function Remove-Licenses {

  [CmdletBinding()]
  Param(
    $usersToRemove,
    $license
  )

  $sku = Get-LicenseDetails -license $license.Name
  $licenseName = $license.Name

  Foreach($user in $usersToRemove){

    # If the user has multiple licenses assigned, they will have multiple rows returned - so just get the first
    $upn = $allLicensedUsers | Where { $_.UserId -eq $user } | Select -First 1 -ExpandProperty UserPrincipalName
    # Remove the license from the user
    If($upn -match "smithsonline.onmicrosoft.com"){
      Write-SmithsLog -Level DEBUG -Message "$updateType [$licenseName] [$upn]: Not unlicensing (cloud user)"
    }
    Else {
      Write-SmithsLog -Level DEBUG -Message "$updateType [$licenseName] [$upn]: Unlicensing"
      If(-not $ReadOnly){
        Try {
          Set-MsolUserLicense -ObjectId $user -RemoveLicenses $sku.AccountSkuId
          $successCount++
        }
        Catch {
          Write-SmithsLog -Level ERROR -Message "[O365 UPDATE ERROR] [$licenseName] [$upn]: $($_.Exception.Message)"
        }
      }
    }

    If($usersToRemove.Count -eq 0){
      Write-SmithsLog -Level INFO -Message "$updateType [$licenseName] [COMPLETED]: No users to license"
    }
    Else {
      Write-SmithsLog -Level INFO -Message "$updateType [$licenseName] [COMPLETED]: $successcount successes, $errorCount failures, $skipCount skipped"
    }
  }
}

main

