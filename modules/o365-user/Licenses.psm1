[CmdletBinding()]
Param()

$script:activity = "Licensing"
$script:successes = 0
$script:failures = 0
$script:deferred = 0

$blockedOUs = Get-SmithsConfigSetting -Component "Active Directory" -Name "Exclude Sites"

<#

Function Add-SmithsLicenses {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalName,
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$License,
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$LicenseName,
    [switch]$ReadOnly
  )

  Begin {
  }

  Process {
    Write-SmithsLog -Level DEBUG -Activity $script:activity -Identity $UserPrincipalName -Message "Adding license $LicenseName"
    If(-not $ReadOnly){
      Try {
        Set-MsolUserLicense -UserPrincipalName $UserPrincipalName -AddLicenses $License -ErrorAction Stop
        $script:successes++
      }
      Catch {
        Write-SmithsLog -Level ERROR -Activity $script:activity -Identity $UserPrincipalName -Message "Unable to add license ${LicenseName}: $($_.Exception.Message)"
        $script:failures++
      }
    }
    Else {
      $script:deferred++
    }
  }

  End {
  }
}

Function Remove-SmithsLicenses {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalName,
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$License,
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$LicenseName,
    [switch]$ReadOnly
  )

  Begin {
  }

  Process {
    Write-SmithsLog -Level DEBUG -Activity $script:activity -Identity $UserPrincipalName -Message "Removing license $LicenseName"
    If(-not $ReadOnly){
      Try {
        Set-MsolUserLicense -UserPrincipalName $UserPrincipalName -RemoveLicenses $License -ErrorAction Stop
        $script:successes++
      }
      Catch {
        Write-SmithsLog -Level ERROR -Activity $script:activity -Identity $UserPrincipalName -Message "Unable to remove license ${LicenseName}: $($_.Exception.Message)"
        $script:failures++
      }
    }
    Else {
      $script:deferred++
    }
  }

  End {
  }
}
#>

Function Update-SmithsLicenses {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalName,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Hashtable]$Changes,
    [switch]$ReadOnly
  )

  $addskus = $Changes.Add | Select -ExpandProperty License
  $addlicenses = $Changes.Add | select -ExpandProperty LicenseName
  $removeskus = $Changes.Remove | Select -ExpandProperty License
  $removelivenses = $Changes.Remove | Select -ExpandProperty LicenseName

  Write-SmithsLog -Level DEBUG -Activity $script:activity -Identity $UserPrincipalName -Message "Adding licenses $addlicenses and removing license $removelicenses"
  If(-not $ReadOnly){
    Try {
      Set-MsolUserLicense -UserPrincipalName $UserPrincipalName -AddLicenses $addskus -RemoveLicenses $removeskus -ErrorAction Stop
      $script:successes++
    }
    Catch {
      Write-SmithsLog -Level ERROR -Activity $script:activity -Identity $UserPrincipalName -Message "Unable to make license changes: $($_.Exception.Message)"
      $script:failures++
    }
  }
  Else {
    $script:deferred++
  }
}

Function Update-CloudUsers {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser[]]$Users,
    [Object[]]$CloudUsers,
    [switch]$ReadOnly
  )

  $userchanges = @{}

  $adds = New-Object System.Collections.ArrayList
  $removes = New-Object System.Collections.ArrayList

  $licenses = Get-SmithsConfigGroupSetting -Component Licensing
  $skus = Get-MsolAccountSku

  $licenseRemovalUsers = New-Object System.Collections.ArrayList

  Foreach($license in $licenses){

    $sku = $skus | Where { $_.SkuPartNumber -eq $license.Name }
    $licenseSkuId = $sku.AccountSkuId

    # Identify users in the AD group(s) for this license

    # OK, so apparently there's a limitation in AD Web Services
    # Get-ADGroupMember stops working when there are more than 5,000 members in the group
    # So, let's do this another way.

    [string[]]$licenseGroupDNs = $license | Select -ExpandProperty Include
    [string[]]$licenseGroupMembers = $Users | Where { $_.extensionAttribute4 -ne "GAL" -and ($_.memberOf | Where { $_ -in $licenseGroupDNs }).Count -gt 0 -and $_.physicalDeliveryOfficeName -notin $blockedOUs } | Select -ExpandProperty UserPrincipalName

    # Identify the users in O365 who already have this license

    [string[]]$usersWithLicense = [string[]]($CloudUsers | Where { $licenseSkuId -in $_.Licenses } | Select -ExpandProperty UserPrincipalName)

    # Select users that are in the first list but not the second
    # These are the users who are in the AD group but do not have the license
    # They need this license adding

    $needLicenseAdding = $licenseGroupMembers | Where { $_ -notin $usersWithLicense }
    Foreach($add in $needLicenseAdding){
      If($add -notin $userchanges.Keys){
        $userchanges.$add = @{
          UserPrincipalName = $add
          Add = (New-Object System.Collections.ArrayList)
          Remove = (New-Object System.Collections.ArrayList)
        }
      }
      $index = $userchanges.$add.Add.Add([PSCustomObject]@{
        License = $licenseSkuId
        LicenseName = $license.Description
      })
    }

    # Select users that are in the second list but not the first
    # As an additional step, do not select users
    # These are the users who have the license but are not in the AD group
    # They need the license removing

    $needLicenseRemoving = $usersWithLicense | Where { $_ -notin $licenseGroupMembers }
    $safetyOverride = Get-SmithsConfigSetting -Component "Office 365" -Name "Licensing Override"

    # As a safety measure, skip removal of licenses if attempting to remove more than 100 or more than 25%
    #
    $needsOverride = ($needLicenseRemoving.Count -ge 100 -or (100 * $needLicenseRemoving.Count / $sku.ConsumedUnits) -ge 25)

    If($needsOverride -and $safetyOverride -ne $true){
      Write-SmithsLog -Level WARN -Activity $script:activity -Message "$($license.Description): removal of $($needLicenseRemoving.Count) licenses exceeds safety threshold and requires override"
      Foreach($u in $needLicenseRemoving){
        $ul = [PSCustomObject]@{
          User = $u
          License = $license.Description
        }
        $x = $licenseRemovalUsers.Add($ul)
      }
    }
    Else {
      If($needsOverride -and $safetyOverride){
        Write-SmithsLog -Level WARN -Activity $script:activity -Message "$($license.Description): removal of $($needLicenseRemoving.Count) licenses exceeds safety threshold and override has been provided"
      }
      Foreach($remove in $needLicenseRemoving){
        # Check to see if the user is a real AD user
        # If not, the UPN is probably out of sync - so don't remove the license

        $u = [Microsoft.ActiveDirectory.Management.ADUser[]](Get-ADUser -Filter {UserPrincipalName -eq $remove})
        If($u.Count -eq 1){
          If($remove -notin $userchanges.Keys){
            $userchanges.$remove = @{
              UserPrincipalName = $remove
              Add = (New-Object System.Collections.ArrayList)
              Remove = (New-Object System.Collections.ArrayList)
            }
          }
          $index = $userchanges.$remove.Remove.Add([PSCustomObject]@{
            License = $licenseSkuId
            LicenseName = $license.Description
          })
        }
        Else {
          Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "Licensed user '$remove' not found in Active directory"
        }
      }
      If(($sku.ConsumedUnits + $needLicenseAdding.Count - $needLicenseRemoving.Count) -gt $sku.ActiveUnits){
        Write-SmithsLog -Level ERROR -Activity $script:activity -Message "$($license.Description): $($sku.ConsumedUnits) currently licenses in use, $($sku.ActiveUnits - $sku.ConsumedUnits) licenses available, $($needLicenseAdding.Count - $needLicenseRemoving.Count) licenses needed, shortfall of $($sku.ConsumedUnits + $needLicenseAdding.Count - $needLicenseRemoving.Count - $sku.ActiveUnits) licenses"
      }
    }

    Write-SmithsLog -Level INFO -Activity $script:activity -Message "$($license.Description): $($needLicenseAdding.Count) users need license adding"
    Write-SmithsLog -Level INFO -Activity $script:activity -Message "$($license.Description): $($needLicenseRemoving.Count) need license removing"$simulation


  }
  # We process everything at the end so that if a user has one license added and
  # a different license taken away, there is not a conflict. For example, an error
  # occurs if you try to assign an Exchange Online Plan 2 license before you remove
  # a Plan 1 license.
  #
  # So, we process all the removes first, and then process all the adds.

  #$removes | Remove-SmithsLicenses -ReadOnly:$ReadOnly
  #$adds | Add-SmithsLicenses -ReadOnly:$ReadOnly
  Foreach($change in $userchanges.GetEnumerator()){
    Update-SmithsLicenses -UserPrincipalName $change.Name -Changes $change.Value -ReadOnly:$ReadOnly
  }

  $licenseRemovalUsers | Export-CSV -NoTypeInformation -Path "$SmithsRoot/logs/users-need-licenses-removing.csv"

  Write-SmithsLog -Level INFO -Activity $script:activity -Message "$($script:successes) successes, $($script:failures) failures, $($script:deferred) deferred (read-only)"

}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  @("memberOf", "physicalDeliveryOfficeName", "extensionAttribute4")

}

Function Get-Priority {

  [CmdletBinding()]
  Param()

  20

}
