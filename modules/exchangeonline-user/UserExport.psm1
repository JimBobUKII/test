[CmdletBinding()]
Param()

$script:activity = "Retention Policy"
$script:filebase = "office365-mailusers"
$script:exportstarted = $false

Function Export-MailUsers {
  [CmdletBinding()]
  Param(
    [Object[]]$UserData
  )

  If(-not $script:exportstarted){
    $script:exportpath = "$SmithsRoot/export/$($script:filebase)-$((Get-Date).ToString("yyyy-MM-dd-HH-mm-ss")).csv"
  }

  $UserData | Select UserPrincipalName, PrimarySmtpAddress, @{Label="ProxyAddresses"; Expression={$_.EmailAddresses -join ";"}}, RecipientTypeDetails, WhenCreated, WhenChanged, @{Label="ShowInAddressLists"; Expression={-not $_.HiddenFromAddressListsEnabled}} | Export-Csv -Path $script:exportpath -NoTypeInformation -Encoding utf8 -Append:($script:exportstarted)

  $script:exportstarted = $true
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


  Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "Exporting mailbox data"
  Export-MailUsers -Userdata $mailboxes
  Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "Exporting mail user data"
  Export-MailUsers -UserData (Get-MailUser -ResultSize Unlimited)

  $fileshare = Get-SmithsConfigSetting -Component "Exchange Online" -Name "Export File Share"
  Copy-Item -Path $script:exportpath -Destination "$fileshare\$($script:filebase).csv" -Force

  $domainbase = "office365-domains"
  $domainpath = "$SmithsRoot/export/$($domainbase)-$((Get-Date).ToString("yyyy-MM-dd-HH-mm-ss")).csv"
  Get-SmithsAADDomains | Select Name,IsInitial,IsDefault,IsVerified,AuthenticationType | Export-Csv -Path $domainpath -NoTypeInformation -Encoding utf8
  Copy-Item -Path $domainpath -Destination "$fileshare\$($domainbase).csv" -Force
}

Function Get-Priority {

  [CmdletBinding()]
  Param()

  40

}

