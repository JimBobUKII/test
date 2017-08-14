[CmdletBinding()]
Param()

$holdGroupMembers = Get-SmithsConfigSetting -Component "Active Directory" -Name "Morpho Legal Hold Group" | Get-DistributionGroupMember -ResultSize Unlimited | Select -ExpandProperty PrimarySmtpAddress
$script:activity = "Morpho Litigation Hold"

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

  $licenseCount = ($User.memberOf | Where { $allLicenseGroups -contains $_ }).Count

  $interested = [Object[]]($Mailboxes | Where { $_.PrimarySmtpAddress -in $holdGroupMembers })
  Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "$($interested.Count) mailboxes found that should have litigation hold enabled"
  Foreach($mb in $interested){
    If($mb.MailboxPlan -match "^ExchangeOnlineEnterprise"){

      # Has Exchange Enterprise (Exchange Online Plan 2, E3, E5 etc.)

      If(-not ($mb.LitigationHoldEnabled -and $mb.LitigationHoldDuration -eq "3650.00:00:00")){
        Write-SmithsLog -Level DEBUG -Activity $script:activity -Identity $mb.PrimarySmtpAddress -Message "Correct license assigned but litigation hold not already enabled and/or not set to 10 years"
        If(-not $ReadOnly){
          Set-Mailbox -Identity $mb.SamAccountName -LitigationHoldEnabled $true -LitigationHoldDuration 3650
        }
        Write-SmithsLog -Level DEBUG -Activity $script:activity -Identity $mb.PrimarySmtpAddress -Message "Litigation hold enabled and set to 10 years"
      }
    }
    # Else, mailbox has an Exchange Online Kiosk or Plan 1 license so do nothing
  }

  Remove-Variable -Name "interested"



}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  [string[]]@()

}

Function Get-Priority {

  [CmdletBinding()]
  Param()

  70

}
