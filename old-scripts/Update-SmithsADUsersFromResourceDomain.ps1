[CmdletBinding()]
Param(
  [switch]$ReadOnly,
  [switch]$TestUsers,
  [string]$CustomFilter = "",
  [string]$ResourceOU
)

Function Get-LDAPFilter {

  $samAccountType= 0x30000000
  $filterStack = @("(SAMAccountType=$sAMAccountType)", "(mailNickname=*)")
  If($CustomFilter -ne "" -and $CustomFilter -ne $null){
    $filterStack += $CustomFilter
  }
  If($TestUsers){
    $testusers = Get-SmithsConfigSetting -Component "Active Directory" -Name "Test Users"
    $userfilter = "(|"
    Foreach($u in $testusers){
      $userfilter += "(samaccountname=$u)"
    }
    $userfilter += ")"
    $filterStack += $userfilter
  }
  $ldapFilter = "(&" + ($filterStack -join "") + ")"
  Write-SmithsLog -Level DEBUG -Message "LDAP filter $ldapFilter"
  $ldapFilter

}

$addressFields = @("streetAddress", "l", "st", "postalCode", "c","telephoneNumber","mobile","facsimileTelephoneNumber","homePhone","telephoneAssistant","title")
$propertiesToLoad = @("samaccountname","displayName","proxyAddresses","mail","msExchHideFromAddressLists","msRTCSIP-PrimaryUserAddress", "msExchMasterAccountSid","distinguishedName")
$propertiesToLoad += $addressFields

Function Get-ResourceUsers {

  [CmdletBinding()]
  Param(
    [string]$LDAPFilter
  )

  $searcher = New-Object System.DirectoryServices.DirectorySearcher

  $searchSCope = Get-SearchScope
  $searcher.SearchRoot = "LDAP://attsmiths.com/$searchScope"
  $searcher.Filter = $LDAPFilter
  #$searcher.PageSize = 1000
  Foreach($attr in $propertiesToLoad){
    $x = $searcher.PropertiesToLoad.Add($attr)
  }
  $data = @()
  $results = $searcher.FindAll()
  $results.GetEnumerator() | Foreach-Object {
    $obj = @{}
    Foreach($attrName in $propertiesToLoad){
      If($_.Properties[$attrName].Count -eq 1){
        $obj[$attrName] = $_.Properties[$attrName][0]
      }
      ElseIf($_.Properties[$attrName].Count -gt 1) {
        $obj[$attrName] = $_.Properties[$attrName]
      }
      Else {
        $obj[$attrName] = $null
      }
    }
    $data += $obj

  }
  $data
}

Function Get-SidFilter {

  [CmdletBinding()]
  Param(
    $Sid
  )

  $sidObj = New-Object System.Security.Principal.SecurityIdentifier($Sid, 0)

  "(objectSid=$($sidObj.Value))"
}

Function Update-ADUsers {

  [CmdletBinding()]
  Param(
    $Users
  )

  $blockedDomains = Get-SmithsConfigSetting -Component "Active Directory" -Name "Blocked Domain Names"
  $searchBase = Get-SmithsConfigSetting -Component "Active Directory" -Name "Search Base"
  $credential = Get-SmithsConfigSetting -Component "Active Directory" -Name "Credential"

  $successcount = 0
  $failurecount = 0
  $skipcount = 0

  Foreach($resourceUser in $Users){
    $username = $resourceUser.sAMAccountName
    If($resourceUser.msExchMasterAccountSid -eq $null){
      $adUser = $null
    }
    Else {
      $sidFilter = Get-SidFilter -Sid $resourceUser.msExchMasterAccountSid

      #$adUser = Get-ADUser -Identity $resourceUser.sAMAccountName -ErrorAction Stop -Properties $propertiesToLoad
      $adUser = Get-ADUser -LDAPFilter $sidFilter -ErrorAction SilentlyContinue -Properties $propertiesToLoad
      If($adUser -eq $null){
        #$adUser = $null

        # Try with the username

        $adUser = Get-ADUser -LDAPFilter "(samaccountname=$username)" -Properties $propertiesToLoad -ErrorAction SilentlyContinue
        If($adUser -ne $null){
          "Invalid msExchMasterAccountSid for $username but found username match" | Out-File errors.txt -Append -encoding UTF8
        }
        Else {
          $adUser = $null
        }

      }

    }
    If($adUser -ne $null){

      $adUsername = $adUser.SamAccountName
      If($username -ne $adUsername){
        "Username mismatch ATTSMITHS = $username SMITHSNET = $adUsername" | Out-File "username-mismatches.txt" -Append -Encoding UTF8
      }

      # Take the current proxyAddresses in AD and strip out all SMTP, smtp, X400, andX500 addresses
      # That should leave SIP, and anything else we want to keep
      $newProxyAddresses = @()

      # Yes, actually exclude SIP
      # The correct proxyAddresses entry is lowercase sip:
      Foreach($pa in $adUser.proxyAddresses){
        If($pa -cnotmatch "^(SMTP|smtp|X500|X400|SIP):"){
          $newProxyAddresses += $pa
        }
      }
      $newMail = ""
      $update = $True
      Foreach($resourcePA in $resourceUser.proxyAddresses){

        # Split the proxyAddress into <type>:<value>

        $proxyAddressType, $proxyAddressValue = $resourcePA -split ":"

        # Copy smtp: and SMTP: proxyAddresses into the new list, if they are not a blocked domain

        Switch -CaseSensitive ($proxyAddressType){
          "smtp" {
            $user, $domain = $proxyAddressValue -split "@"
            If($domain -notin $blockedDomains){
              If($user -notmatch "^msRTCSIP-"){
                If($resourcePA -cnotin $newProxyAddresses){
                  $newProxyADdresses += $resourcePA
                }
                #Write-SmithsLog -Level DEBUG -Message "[AD UPDATE] [$username] Copying proxyAddress '$resourcePA'"
              }
              Else {
                #Write-SmithsLog -Level DEBUG -Message "[AD UPDATE] [$username] Skipping proxyAddress '$resourcePA', is msRTCSIP-"
              }
            }
            Else {
              #$newProxyAddresses += "smtp:$adUsername@$divisionalDomain"
              #Write-SmithsLog -Level DEBUG -Message "[AD UPDATE] [$username] Skipping proxyAddress '$resourcePA', blocked domain"
            }
          }
          "SMTP" {
            $user, $domain = $proxyAddressValue -split "@"
            If($domain -notin $blockedDomains){
              If($proxyAddressValue -eq $resourceUser.mail){
                $newProxyADdresses += $resourcePA
                #Write-SmithsLog -Level DEBUG -Message "[AD UPDATE] [$username] Copying proxyAddress '$resourcePA'"
                $newMail = $resourceUser.mail
              }
              Else {
                #$update = $false
                #Write-SmithsLog -Level WARN -Message "[AD UPDATE WARNING] [$username] Primary SMTP proxyAddress and mail attributes do not match!"
                "$($resourceUser.mail) $resourcePA mismatch between mail and proxy SMTP" | Out-File errors.txt -Append
              }
            }
            Else {
              $newMail = $aduser.UserPrincipalName
              $newProxyAddresses += "SMTP:$newMail"
              "$resourcePA remapped to SMTP:$newMail samaccountname $adUsername" | Out-File remapped-blocked-domains.txt -Append
              #Write-SmithsLog -Level DEBUG -Message "[AD UPDATE WARNING] [$username] Skipping proxyAddress '$resourcePA', blocked domain'"
              #$update = $false
            }
          }
          default {
            #Write-SmithsLog -Level DEBUG -Message "[AD UPDATE] [$username] Skipping proxyAddress '$resourcePA', invalid type"
          }
        }
      }
      If($adUser."msRTCSIP-PrimaryUserAddress"){
        If($adUser."msRTCSIP-PrimaryUserAddress" -eq "sip:$newMail"){
          $sipCount = $newProxyAddresses | Where { $_ -cmatch "^sip:" }
          If($sipCount.Count -eq 0){
            $newProxyAddresses += $adUser."msRTCSIP-PrimaryUserAddress".ToString()
            #Write-SmithsLog -Level DEBUG -Message "[AD UPDATE] [$username] Adding proxyAddress '$($adUser."msRTCSIP-PrimaryUserAddress")'"
          }
          Else {
            #Write-SmithsLog -LEVEL WARN -MEssage "[AD UPDATE] [$username] SIP proxyAddress already present, skipping"
          }
        }
        Else {
          #Write-SmithsLog -Level WARN -Message "[AD UPDATE WARNING] [$username] Primary SMTP proxyAddress and msRTCSIP-PrimaryUserAddress attributes do not match!"
        }
      }
      $Changes = @{
        mail = @{Type = "Set"; Value = $newMail}
        proxyAddresses = @{Type = "Set"; Value = $newProxyAddresses}
        msExchHideFromAddressLists = @{Type = "Set"; Value = $resourceUser.msExchHideFromAddressLists}
      }
      If($resourceUser.streetAddress -ne $null -And $resourceUser.streetADdress -ne "" -and $resourceUser.c -ne $null -and $resourceUser.c -ne ""){
        Foreach($field in $addressFields){
          If($resourceUser.$field -ne $null){
            $fieldValue = $resourceUser.$field.Trim()
          }
          Else{
            $fieldValue = $null
          }
          $changes.$field = @{Type = "Set"; Value = $fieldValue}
        }
      }
      If($resourceUser.title = "Resource Mailbox"){
        $changes.adminDescription = @{Type = "Set"; Value = $null}
      }
      $Params = @{
        "-Identity" = $adUser.SamAccountName
        "-Changes" = $changes
        "-ReadOnly" = $ReadOnly
        "-Credential" = $credential
        "-ObjectType" = "USER"
        "-Object" = $adUser
      }

      $success, $failure, $skip = Set-SmithsADObject @params

    }
    Else {
      $skip = 0
      $success = 0
      $failure = 1
      Write-SmithsLog -Level ERROR -Message "[AD UPDATE ERROR] [$username] Cannot find AD user"
      "AD user not found for $username in smithsnet" | Out-File missing-users.txt -Append -encoding UTF8
    }
    $successcount += $success
    $failurecount += $failure
    $skipcount += $skip


  }
  Write-SmithsLog -Level INFO -Message "[AD UPDATE COMPLETED] $successcount successes, $failurecount failures, $skipcount skipped"

}

Function Get-SearchScope {

  [CmdletBinding()]
  Param()

  If($ResourceOU -eq $null -or $ResourceOU -eq ""){
    "DC=attsmiths,dc=com"
  }
  Else {
    $csv = Import-CSV -Path "$PSScriptRoot/attsmiths-ous.csv"
    ($csv | Where { $_.ou -eq $ResourceOU }).DN
  }

}

Function main {

  Import-Module -Name (Resolve-Path -Path "$PSScriptRoot/../modules/Smiths.psm1") -Force
  Import-SmithsModule -Name "SmithsLogging.psm1"
  Import-SmithsModule -Name "SmithsAD.psm1"
  Import-SmithsModule -Name "SmithsDynamicModules.psm1"

  Import-SmithsConfig

  $ldapFilter = Get-LDAPFilter
  $resourceUsers = Get-ResourceUsers -LDAPFilter $ldapFilter
  Update-ADUsers -Users $resourceUsers

}

main

