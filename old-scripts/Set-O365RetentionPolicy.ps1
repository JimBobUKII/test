<#
.SYNOPSIS
    Automatically sets retention policy based on group membership.
.DESCRIPTION
    Based on group membership (groups defined in the XML file), sets the retention policy for each mailbox.
    If a user is not a member of any of the listed groups, the default retention policy is assigned instead.
.NOTES
    Author: David Gee

    Version History:
    Version   Date        Author                Changes
    1.0       08/29/2016  David Gee             Initial release
#>
[CmdletBinding()]
Param()

Function main {
  Import-Module -Name (Join-Path $PSScriptRoot "O365.psm1") -Force
  Import-Module -Name (Join-Path $PSScriptRoot "O365Logging.psm1") -Force
  Import-Module -Name (Join-Path $PSScriptRoot "O365ExchangeOnline.psm1") -Force
  Import-SmithsConfig
  Connect-SmithsO365
  $eolsession = Connect-ExchangeOnline
  $importedsession = Import-PSSession -Session $eolsession

  # Removing mailbox features is much slower because every mailbox muset be enumerated.
  # Therefore, this only runs once a week.
  #
  $policies = Get-SmithsConfigGroupSetting -Component "Retention Policies"

  Set-O365RetentionPolicy -Policies $policies

  Disconnect-ExchangeOnline
}

Function Set-O365RetentionPolicy {

  Param(
    [Object[]]$Policies
  )

  $pmembers = @{}

  Foreach($p in $policies){

    If($p.GroupId -ne $null){
      $members = Get-O365GroupMembers -GroupId $p.GroupId | Select -ExpandProperty UserPrincipalName
      Foreach($member in $members){
        $pmembers[$member] = $p.Name
      }

    }
    Else {
      $defaultpolicy = $p.Name
    }
  }

  $allMailboxes = Get-Mailbox -ResultSize Unlimited
  $successcount = 0
  $failurecount = 0
  Foreach($mbox in $allMailboxes){

    $assignedpolicy = $mbox.RetentionPolicy

    # If UPN is in exception lists
    If($pmembers.ContainsKey($mbox.UserPrincipalName)){

      # Change retention policy if incorrect
      $targetpolicy = $pmembers[$mbox.UserPrincipalName]
      If($assignedpolicy -ne $targetpolicy){
        Write-SmithsLog -Level DEBUG "Setting retention policy `"$targetpolicy`" for $($mbox.UserPrincipalName)"
        Set-Mailbox -Identity $mbox.UserPrincipalName -RetentionPolicy $targetpolicy
        If($?){
          $successcount++
        }
        Else {
          $failurecount++
          Write-SmithsLog -Level ERROR "Error setting retention policy `"$targetpolicy`" for $($mbox.UserPrincipalName): $($error[0].Exception.Message)"
        }

      }


    }
    # Otherwise, assign the default policy if not already assigned
    Else {
      If($assignedpolicy -ne $defaultpolicy){
        Write-SmithsLog -Level DEBUG "Setting retention policy `"$defaultpolicy`" for $($mbox.UserPrincipalName)"
        Set-Mailbox -Identity $mbox.UserPrincipalName -RetentionPolicy $defaultpolicy
        If($?){
          $successcount++
        }
        Else {
          $failurecount++
          Write-SmithsLog -Level ERROR "Error setting retention policy `"$targetpolicy`" for $($mbox.UserPrincipalName): $($error[0].Exception.Message)"
        }
      }
    }

  }

  Write-SmithsLog -Level INFO "Processing completed. $successcount succeeded, $failurecount failed."


}


main
