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
  [Parameter(Mandatory=$False)]
  [System.Management.Automation.PSCredential]$Credential
)

Function main {
  Import-Module -Name (Join-Path $PSScriptRoot "O365.psm1") -Force
  Import-Module -Name (Join-Path $PSScriptRoot "O365Logging.psm1") -Force
  Import-Module -Name (Join-Path $PSScriptRoot "O365ExchangeOnline.psm1") -Force
  Import-SmithsConfig
  Connect-SmithsO365
  $importedsession = Connect-ExchangeOnline | Import-PSSession
  $features = Get-SmithsConfigGroupSetting -Component "Mailbox Features"

  # Removing mailbox features is much slower because every mailbox muset be enumerated.
  # Therefore, this only runs once a week.

  $dayofweek = Get-SmithsConfigSetting -Component "Mailbox Features" -Name "remove-features-on"
  $dow = [System.DayOfWeek]::$dayofweek
  If($dow -eq $null){
    Write-SmithsLog -Level WARN -Message "Invalid entry for feature removal '$dayofweek'"
  }

  If((Get-Date).DayOfWeek -eq $dow){
    Disable-O365MailboxFeatures -Features $features
  }

  # Every time the script is run, enable mailbox features
  Enable-O365MailboxFeatures -Features $features


  Disconnect-ExchangeOnline
}

Function Enable-O365MailboxFeatures {

  Param(
    [Object[]]$Features
  )

  Foreach($f in $features){

    $successcount = 0
    $failurecount = 0

    Write-SmithsLog -Level INFO -Message "$($f.Group): Beginning processing"
    $members = Get-O365GroupMembers -GroupId $f.GroupId | Select -ExpandProperty UserPrincipalName
    Foreach($member in $members){
      $params = @{
        "-Identity" = $member
        "-$($f.Name)" = $True
        "-ErrorAction" = "stop"
      }
      Set-CASMailbox @params
      If($?){
        $successcount++
      }
      Else {
        Write-SmithsLog -Level ERROR -Message "$($f.Group): Error enabling $($f.Name) for $member: $($error[0].Exception.Message)"
        $failurecount++
      }
    }
    Write-SmithsLog -Level INFO -Message "$($f.Group): Enabling features complete. $successcount succeeded, $failurecount failed."

  }

}

Function Disable-O365MailboxFeatures {

  Param(
    [Object[]]$Features
  )

  $allMailboxes = Get-Mailbox -ResultSize unlimited

  Foreach($f in $features){

    $params = @{
      "-$($f.Name)" = $False
    }

    $successcount = 0
    $failurecount = 0

    Write-SmithsLog -Level INFO -Message "$($f.Group): Beginning processing"
    $members = Get-O365GroupMembers -GroupId $f.GroupId | Select -ExpandProperty UserPrincipalName

    Foreach($mailbox in $allMailboxes){
      If($members -notcontains $mailbox.UserPrincipalName){
        $mailbox | Set-CasMailbox @params
        If($?){
          $successcount++
        }
        Else {
          Write-SmithsLog -Level ERROR -Message "$($f.Group): Error disabling $($f.Name) for $($mailbox.UserPrincipalName): $($error[0].Exception.Message)"
          $failurecount++
        }
      }
    }
    Write-SmithsLog -Level INFO -Message "$($f.Group): Disabling features complete. $successcount succeeded, $failurecount failed."

  }

}


main
