[CmdletBinding()]
Param()

$script:activity = "Proxy Addresses"

Function Get-Changes {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser]$User
  )

  $changes = @{}

  $newProxies = New-Object System.Collections.ArrayList

  # This script deliberately only allows SMTP/smtp and SIP addresses.
  # Anything else is dropped.

  # Process SMTP/smtp addresses
  If(-not (Test-NullOrBlank -Value $user.mail)){

    $hasInternalAddress = Test-SmithsAADAddress -Address $User.mail

    # User is not a GAL-only contact and has an address with a Smiths-owned e-mail domain
    If($User.extensionAttribute4 -ne "GAL" -and $hasInternalAddress){
      Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Message "E-mail user with internal address" -Activity $script:activity

      # Add the primary
      $x = $newProxies.Add("SMTP:$($User.mail)")
    }
    ElseIf($User.extensionAttribute4 -eq "GAL" -and -not $hasInternalAddress){
      Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Message "GAL contact with external targetAddress $($User.mail)." -Activity $script:activity
      $changes.targetAddress = @{Type = "Replace"; Value = $User.mail}
      # Add the primary
      $x = $newProxies.Add("SMTP:$($User.mail)")
    }
    Else {
      #   is either set as a GAL-only contact with an internal address
      #   or is a user with an external address
      #   either way, don't set a primary SMTP address
      Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Message "Not setting primary SMTP proxy address, GAL contact with internal address or user with external address" -Activity $script:activity
    }
    # Keep the existing secondary proxies if they are Smiths domains
    $mailProxies = [string[]]($User.proxyAddresses | Where { $_ -cmatch "^smtp:" })
    $mailProxies | Where { (-not (Test-NullOrBlank -Value $_)) -and $_ -ne "smtp:$($User.mail)" -and (Test-SmithsAADAddress -Address ($_.Substring(5))) } | Foreach-Object {
      $x = $newProxies.Add($_)
    }
    $mailPrimaryProxy = [string]($User.proxyAddresses | Where { $_ -cmatch "^SMTP:" } | Select -First 1)
    # If the primary proxy is different from the primary mail
    If(-not (Test-NullOrBlank -Value $mailPrimaryProxy) -and $mailPrimaryProxy -ne "SMTP:$($User.mail)"){
      $oldPrimary = $mailPrimaryProxy -creplace "^SMTP:", "smtp:"
      # If the old primary (now a secondary) isn't already in the list, add it
      If($oldPrimary -notin $mailProxies -and (Test-SmithsAADAddress -Address $oldPrimary.Substring(5))){
        $x = $newProxies.Add($oldPrimary)
      }
    }
  }
  If(-not (Test-NullOrBlank -Value $User."msRTCSIP-PrimaryUserAddress")){
    $sipProxy = $User."msRTCSIP-PrimaryUserAddress" -creplace "^sip:", "SIP:"
      Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Message "Skype for Business address $($User."msRTCSIP-PrimaryUserAddress")." -Activity $script:activity
    $x = $newProxies.Add($sipProxy)
  }
  If($newProxies.Count -gt 0){
    $sortedProxies = $newProxies | Sort -CaseSensitive
    $changes.proxyAddresses = @{Type = "Set"; Value = [string[]]$sortedProxies}
  }
  Else {
    $changes.proxyAddresses = @{Type = "Clear"}
  }
  $changes
}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  [string[]]@("mail", "proxyAddresses", "msRTCSIP-PrimaryUserAddress", "extensionAttribute4", "targetAddress")

}

Function Get-Priority {

  [CmdletBinding()]
  Param()

  90

}

