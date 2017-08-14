[CmdletBinding()]
Param()

$script:o365RetentionPolicies = Get-SmithsConfigGroupSetting -Component "Retention Policies"
$defaultPolicyName = Get-SmithsConfigSetting -Component "Exchange Online" -Name "Default Retention Policy"
$script:activity = "Retention Policy"
$script:successes = 0
$script:failures = 0
$script:unchanged = 0
$script:deferred = 0

Function Set-SmithsRetentionPolicy {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [Object]$Mailbox,
    [Parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string]$RetentionPolicy,
    [switch]$ReadOnly
  )

  Begin {
  }

  Process {
    Write-SmithsLog -Level DEBUG -Activity $script:activity -Identity $Mailbox.PrimarySmtpAddress -Message "Setting retention policy to '$RetentionPolicy'"
    If(-not $ReadOnly){
      Set-Mailbox -Identity $Mailbox.SamAccountName -RetentionPolicy $RetentionPolicy
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

  $retentionUsers = @{}
  #$allNonDefaultUsers = [string[]]($o365RetentionPolicies | Select -ExpandProperty Include | Get-SmithsADGroupMember -Filter "(mail=*)" -Properties mail | Select -ExpandProperty mail | Select -Unique)
    #$retentionUsers[$policy.Name] = [string[]]($policy | Select -ExpandProperty Include | Get-SmithsADGroupMember -Filter "(mail=*)" -Properties mail | Select -ExpandProperty mail)
  #}

  $processedUsers = [string[]]@()

  # Policies are defined in the config file in order longest to shortest
  # Process the policies in the same order, and each time only add users who
  # haven't been added to a previously-processed (i.e. longer) policy

  Foreach($policy in $o365RetentionPolicies){

    $policyUsers = [string[]]($policy | Select -ExpandProperty Include | Get-SmithsADGroupMember -Filter "(mail=*)" -Properties mail | Select -ExpandProperty mail | Where { $_ -notin $processedUsers })

    $retentionUsers[$policy.Name] = $policyUsers
    $processedUsers += $policyUsers
  }

  $allNonDefaultUsers = [string[]]($processedUsers | Select -Unique)

  # Determine who should have the default retention policy, and who actually does
  # Make changes to the difference

  $mailboxes | Where { $_.PrimarySmtpAddress -notin $allNonDefaultUsers -and $_.RetentionPolicy -ne $defaultPolicyName } | Set-SmithsRetentionPolicy -RetentionPolicy $defaultPolicyName -ReadOnly:$ReadOnly
  $correctPolicyUsers = $mailboxes | Where { $_.PrimarySmtpAddress -notin $allNonDefaultUsers -and $_.RetentionPolicy -eq $defaultPolicyName }
  Write-SmithsLog -Level Debug -Activity $script:activity -Message "$($correctPolicyUsers.Count) users already have retention policy '$defaultPolicyName' correctly set, skipping"
  $script:unchanged += $correctPolicyUsers.Count

  # Then for each retention policy except the manual one, determine who should
  # have the default retention policy, who actually does, and make the changes
  # to the difference

  Foreach($policy in ($retentionUsers.GetEnumerator() | Where { $_.Name -ne "Manual Retention" })){
    $mailboxes | Where { $_.PrimarySmtpAddress -in $policy.Value -and $_.RetentionPolicy -ne $policy.Name } | Set-SmithsRetentionPolicy -RetentionPolicy $policy.Name -ReadOnly:$ReadOnly
    $correctPolicyUsers = $mailboxes | Where { $_.PrimarySmtpAddress -in $policy.Value -and $_.RetentionPolicy -eq $policy.Name }
    Write-SmithsLog -Level Debug -Activity $script:activity -Message "$($correctPolicyUsers.Count) users already have retention policy '$($policy.Name)' correctly set, skipping"
    $script:unchanged += $correctPolicyUsers.Count
  }
  Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "$successes successes, $failures failures, $deferred deferred (read-only), $unchanged unchanged"

  Remove-Variable -Name @("retentionUsers", "allNonDefaultUsers", "correctPolicyUsers")

}

Function Get-Priority {

  [CmdletBinding()]
  Param()

  30

}

