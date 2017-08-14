[CmdletBinding()]
Param()

$script:activity = "Auditing"
$script:successes = 0
$script:failures = 0
$script:unchanged = 0
$script:deferred = 0

Function Update-Mailboxes {

  [CmdletBinding()]
  Param(
    [switch]$ReadOnly
  )

  $script:ownerAuditing = Get-SmithsConfigSetting -Component "Exchange Online" -Name "Owner Auditing"
  $script:delegateAuditing = Get-SmithsConfigSetting -Component "Exchange Online" -Name "Delegate Auditing"
  $script:adminAuditing = Get-SmithsConfigSetting -Component "Exchange Online" -Name "Admin Auditing"

  Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "Starting"
  Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "Fetching mailboxes needing auditing"

  $mailboxes = [Object[]](Get-Mailbox -ResultSize Unlimited -Filter { AuditEnabled -ne $true })
  If($mailboxes.Count -gt 0){
    Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "$($mailboxes.Count) mailboxes found needing auditing enabling"
    $mailboxes | Enable-SmithsMailboxAuditing -ReadOnly:$ReadOnly
  }
  Else {
    Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "No mailboxes found needing auditing enabling"
  }
  Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "$($script:successes) successes, $($script:failures) failures, $($script:deferred) deferred (read-only)"

}

Function Enable-SmithsMailboxAuditing {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [Object]$Mailbox,
    [switch]$ReadOnly
  )

  Begin {
  }

  Process {
    Write-SmithsLog -Level DEBUG -Identity $Mailbox.PrimarySmtpAddress -Activity $script:Activity -Message "Enabling auditing"
    If(-not $ReadOnly){
      Try {
        Set-Mailbox -Identity $Mailbox.SamAccountName -AuditEnabled $true -AuditOwner $script:ownerAuditing -AuditDelegate $script:delegateAuditing -AuditAdmin $script:adminAuditing
        $script:successes++
      }
      Catch {
        Write-SmithsLog -Level DEBUG -Identity $Mailbox.PrimarySmtpAddress -Activity $script:Activity -Message "Error enabling auditing: $($_.Exception.Message)"
        $script:failures
      }
    }
    Else {
      $script:deferred++
    }
  }

  End {
  }

}

Function Get-Priority {

  [CmdletBinding()]
  Param()

  40

}


