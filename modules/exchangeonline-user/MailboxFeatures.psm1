[CmdletBinding()]
Param()

$script:mailboxFeatures = Get-SmithsConfigGroupSetting -Component "Mailbox Features"
$script:activity = "Mailbox Features"
$script:successes = 0
$script:failures = 0
$script:unchanged = 0
$script:deferred = 0

Function Set-SmithsMailboxFeature {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    $CASMailbox,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Feature,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [boolean]$Value,
    [switch]$ReadOnly
  )

  Begin {
  }

  Process {
      Write-SmithsLog -Level DEBUG -Activity $script:activity -Identity $CASMailbox.PrimarySmtpAddress -Message "Setting $Feature to $Value"
      If(-not $ReadOnly){
        $arg = @{"-$Feature" = $Value}
        Set-CASMailbox -Identity $CASMailbox.SamAccountName @arg
        $script:successes++
      }
      Else {
        $script:deferred++
      }
  }

  End {
  }

}

Function Update-CloudObjects {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Object[]]$Mailboxes,
    [Object[]]$CASMailboxes,
    [switch]$ReadOnly,
    [switch]$UpdateAll
  )

  # Foreach feature in the config file (POP, IMAP, OWA, ActiveSync, etc.):

  Foreach($feature in $mailboxFeatures){

    # This is a bit convoluted, but it's the cleanest way to handle this and
    # still have it not break all over the place.
    # Step 1: expand all the Include groups
    # Step 2: Get AD group members
    # Step 3: Get AD users from group members and extract e-mail address

    $adFeatureUsers = [string[]]($feature | Select -ExpandProperty Include | Get-SmithsADGroupMember -Filter "(mail=*)" -Properties mail | Select -ExpandProperty mail)

    $featureName = $feature.Name

    # Find Exchange Online mailboxes whose PrimarySmtpAddress matches the e-mail addresses extracted above
    # These are the users who should have the feature enabled. All others should be disabled.
    # Extract the SamAccountName (NOTE THIS IS DIFFERENT FROM THE SMITHSNET SAMACCOUNTNAME)
    # SamAccountName is the only (or at least most convenient) unique key across mailbox and CAS mailbox

    $featureShouldBeEnabledFor = $Mailboxes | Where { $_.PrimarySmtpAddress -in $adFeatureUsers } | Select -ExpandProperty SamAccountName

    # Find CAS mailboxes where the feature is enabled but the user is not in the list above
    # i.e. those users who need the feature disabling
    # Pass this list to Set-SmithsMailboxFeature to disable the feature

    $casMailboxes | Where { $_.$featureName -and $_.SamAccountName -notin $featureShouldBeEnabledFor } | Set-SmithsMailboxFeature -Feature $featureName -Value $false -ReadOnly:$ReadOnly

    # For logging purposes, capture the number of users who have the feature disabled for whom it should be disabled

    $missingAndCorrect = [Object[]]($casMailboxes | Where { (-not $_.$featureName) -and $_.SamAccountName -notin $featureShouldBeEnabledFor })
    Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "$($missingAndCorrect.Count) users have feature '$featureName' correctly disabled, skipping"
    $script:unchanged += $missingAndCorrect.Count

    # Find CAS mailboxes where the feature is disabled but the user is in the list above
    # i.e. those users who need the feature enabling
    # Pass this list to Set-SmithsMailboxFeature to enable the feature

    $casMailboxes | Where { (-not $_.$featureName) -and $_.SamAccountName -in $featureShouldBeEnabledFor } | Set-SmithsMailboxFeature -Feature $featureName -Value $true -ReadOnly:$ReadOnly

    # For logging purposes, capture the number of users who have the feature enabled for whom it should be enabled

    $presentAndCorrect = [Object[]]($casMailboxes | Where { $_.$featureName -and $_.SamAccountName -in $featureShouldBeEnabledFor })
    Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "$($presentAndCorrect.Count) users have feature '$featureName' correctly enabled, skipping"
    $script:unchanged += $presentAndCorrect.Count

    # Do some cleanup to save memory
    Remove-Variable -Name @("adFeatureUsers", "featureShouldBeEnabledFor", "missingAndCorrect", "presentAndCorrect")

  }

  Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "$successes successes, $failures failures, $deferred deferred (read-only), $unchanged unchanged"


}

Function Get-Priority {

  [CmdletBinding()]
  Param()

  20

}

