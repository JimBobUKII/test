[CmdletBinding()]
Param()

$script:activity = "Resource Mailbox Auto-Accept"
$script:successes = 0
$script:failures = 0
$script:unchanged = 0
$script:deferred = 0

Function Enable-SmithsResourceMailboxAutoAccept {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $Mailbox,
    [switch]$ReadOnly
  )

  Begin {
  }

  Process {

    Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "Enabling auto-accept on $($Mailbox.PrimarySmtpAddress)"
    If($ReadOnly){
      $script:deferred++
    }
    Else {
      Try {
        Set-CalendarProcessing -Identity $Mailbox.SamAccountName -AutomateProcessing AutoAccept
        $script:successes++
      }
      Catch {
        $script:failures++
      }
    }

  }

  End {
  }

}

Function Update-Mailboxes {

  [CmdletBinding()]
  Param(
    [switch]$ReadOnly
  )

  Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "Starting"

  Get-Mailbox -ResultSize Unlimited -Filter { IsResource -eq $True } | Where { (Get-CalendarProcessing $_.SamAccountName).AutomateProcessing -ne "AutoAccept" } | Enable-SmithsResourceMailboxAutoAccept -ReadOnly:$ReadOnly

  Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "Finished, $($script:successes) successes, $($script:deferred) deferred, $($script:failures) failures"

}


Function Get-Priority {

  [CmdletBinding()]
  Param()

  10

}


