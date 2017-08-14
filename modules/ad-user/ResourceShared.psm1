[CmdletBinding()]
Param()

New-Variable -Name RoomMailboxType -Value 0x20 -Option ReadOnly
New-Variable -Name EquipmentMailboxType -Value 0x40 -Option ReadOnly
New-Variable -Name SharedMailboxType -Value 0x60 -Option ReadOnly
New-Variable -Name ProvisionMailboxAction -Value 0x1 -Option ReadOnly
New-Variable -Name DeprovisionMailboxAction -Value 0x8 -Option ReadOnly
New-Variable -Name ProvisionArchiveAction -Value 0x2 -Option ReadOnly
New-Variable -Name DeprovisionArchiveAction -Value 0x10 -Option ReadOnly

$excludeSites = Get-SmithsConfigSetting -Component "Active Directory" -Name "Exclude Sites"

Set-Variable -Name "Values" -Option Constant -Value @{
  Room = @{
    RecipientTypeDetails = [Int64]0x200000000
    RecipientDisplayType = [Int64]0xFFFFFFFF80000706
    Provision = $RoomMailboxType -bor $ProvisionMailboxAction # 1 + 32 = 33
    Deprovision = $RoomMailboxType -bor $DeprovisionMailboxAction # 8 + 32 = 40
  }
  Equipment = @{
    RecipientTypeDetails = [Int64]0x400000000
    RecipientDisplayType = [Int64]0xFFFFFFFF80000806
    Provision = $EquipmentMailboxType -bor $ProvisionMailboxAction # 1 + 64 = 65
    Deprovision = $EquipmentMailboxType -bor $DeprovisionMailboxAction # 8 + 64 = 72
  }
  Shared = @{
    RecipientTypeDetails = [Int64]0x800000000
    RecipientDisplayType = [Int64]0xFFFFFFFF80000606
    Provision = $SharedMailboxType -bor $ProvisionMailboxAction # 1 + 96 = 97
    Deprovision = $SharedMailboxType -bor $DeprovisionMailboxAction # 8 + 96 = 104
  }
  SharedWithoutArchive = @{
    RecipientTypeDetails = [Int64]0x800000000
    RecipientDisplayType = [Int64]0xFFFFFFFF80000606
    Provision = $SharedMailboxType -bor $ProvisionMailboxAction -bor $DeprovisionArchiveAction # 1 + 16 + 96 = 113
    Deprovision = $SharedMailboxType -bor $DeprovisionMailboxAction -bor $DeprovisionArchiveAction # 8 + 16 + 96 = 120
  }
  SharedWithArchive = @{
    RecipientTypeDetails = [Int64]0x800000000
    RecipientDisplayType = [Int64]0xFFFFFFFF80000606
    Provision = $SharedMailboxType -bor $ProvisionMailboxAction -bor $ProvisionArchiveAction # 1 + 2 + 96 = 99
    Deprovision = $SharedMailboxType -bor $DeprovisionMailboxAction -bor $DeprovisionArchiveAction # 8 + 16 + 96 = 120
  }

}
$script:activity = "Mailbox Type"

Function Get-Changes {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser]$User
  )

  If(-not (Test-NullOrBlank -Value $User.extensionAttribute4)){

    # ExtensionAttribute 4 is not null, so this is a room/equipment/shared mailbox

    $ea4 = $User.extensionAttribute4.ToLower()
    If($ea4 -in $Values.Keys){
      If($User.physicalDeliveryOfficeName -notin $excludeSites){
        Write-SmithsLog -Level DEBUG -Message "converting to $ea4 mailbox" -Identity $User.SamAccountName -Activity $script:activity
        @{
          msExchRecipientTypeDetails = @{Type = "Set"; Value = $Values.$ea4.RecipientTypeDetails}
          msExchRecipientDisplayType = @{Type = "Set"; Value = $Values.$ea4.RecipientDisplayType}
          msExchRemoteRecipientType = @{Type = "Set"; Value = $Values.$ea4.Provision}
        }
      }
      Else {
        Write-SmithsLog -Level DEBUG -Message "in a blocked site, skipping" -Identity $User.SamAccountName -Activity $script:activity
      }
    }
    ElseIf($ea4 -eq "GAL"){
      If((Test-SmithsO365Address -Address $User.mail)){
        Write-SmithsLog -Level DEBUG -Message "GAL contact with internal address, skipping" -Identity $User.SamAccountName -Activity $script:activity
      }
      Else {
        Write-SmithsLog -Level DEBUG -Message "marking as GAL entry (no mailbox)" -Identity $User.SamAccountName -Activity $script:activity
        @{
          msExchRecipientTypeDetails = @{Type = "Set"; Value = 128}
          msExchRecipientDisplayType = @{Type = "Set"; Value = 6}
        }
      }
    }
    Else {
      Write-SmithsLog -Level ERROR -Message "unknown mailbox type '$ea4', skipping" -Identity $User.SamAccountName -Activity $script:activity
    }
  }
  Else {

    # ExtensionAttribute 4 is null, so mailbox is not a room/equipment/shared
    # So deprovision it, based on the appropriate mailbox type
    If($User.msExchRemoteRecipientType -ne $null){
      $reason = "extensionAttribute4 null or blank"

      # This logic deprovisions a room/equipment/shared mailbox if previously provisioned

      Switch($User.msExchRecipientTypeDetails){
        $Values.Room.RecipientTypeDetails {
          @{msExchRemoteRecipientType = @{Type = "Set"; Value = $Values.Room.Deprovision}}
          $action = "deprovisioning room mailbox"
        }
        $Values.Equipment.RecipientTypeDetails {
          @{msExchRemoteRecipientType = @{Type = "Set"; Value = $Values.Equipment.Deprovision}}
          $action = "deprovisioning equipment mailbox"
        }
        $Values.Shared.RecipientTypeDetails {
          @{msExchRemoteRecipientType = @{Type = "Set"; Value = $Values.Shared.Deprovision}}
          $action = "deprovisioning shared mailbox"
        }
        default {
          $reason += ", unknown recipient type '$($User.msExchRemoteRecipientType)'"
          $action = "skipping"
        }
      }
      Write-SmithsLog -Level DEBUG -Message "$reason, $action" -Identity $User.SamAccountName -Activity $script:activity
    }
    ElseIf($User.msExchRecipientTypeDetails -eq 128 -and $User.msExchRecipientDisplayType -eq 6){
      Write-SmithsLog -Level DEBUG -Message "deprovisioning GAL contact" -Identity $User.SamAccountName -Activity $script:activity
      @{
        msExchRecipientTypeDetails = @{Type = "Clear"}
        msExchRecipientDisplayType = @{Type = "Clear"}
        msExchRemoteRecipientType = @{Type = "Clear"}
        targetAddress = @{Type = "Clear"}
      }
    }
    Else {
      Write-SmithsLog -Level DEBUG -Message "resource/shared mailbox not previously provisioned, skipping" -Identity $User.SamAccountName -Activity $script:activity
    }
  }
}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  [string[]]@(
    "extensionAttribute4"
    "msExchRecipientTypeDetails"
    "msExchRecipientDisplayType"
    "msExchRemoteRecipientType"
    "physicalDeliveryOfficeName"
    "mail"
    "targetAddress"
  )

}

Function Get-Priority {

  [CmdletBinding()]
  Param()

  70

}



