Function Connect-ExchangeOnline {

  [CmdletBinding()]
  Param(
    [Switch]$ProxyRPS
  )

  $suffix = ""
  If($ProxyRPS){
    $suffix = "?proxymethod=rps"
    $proxymessage = " with ProxyMethod RPS"
  }

  $credential = Get-SmithsConfigSetting -Component "Office 365" -Name "Credential"
  Write-SmithsLog -Level DEBUG -Activity "Connect" -Identity $credential.Username -Message "Connecting to Exchange Online PowerShell$proxymessage"
  $session = Get-PSSession | Where { $_.ComputerName -eq "outlook.office365.com" -and $_.State -eq "Opened" } | Select -First 1


  If($session -eq $null){
    $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://outlook.office365.com/powershell-liveid/$suffix" -Credential $credential -Authentication Basic -AllowRedirection
  }
  $module = Import-PSSession -Session $session -AllowClobber
  Import-Module $module -Global -WarningAction SilentlyContinue

  Write-SmithsLog -Level DEBUG -Activity "Connect" -Identity $credential.Username -Message "Connected to Exchange Online PowerShell"

  # Don't import here because it ends up in the wrong scope

}

Function Disconnect-ExchangeOnline {

  If($script:eosession -ne $null){
    Write-SmithsLog -Level DEBUG -Activity "Connect" -Message "Disconnected from O365 Exchange Online PowerShell"
  }

}


Function Set-ExchangeOnlineMailboxFeatures {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Alias,
    [Parameter(Mandatory=$true)]
    [System.Collections.Hashtable]$Changes,
    [switch]$ReadOnly,
    [Parameter(Mandatory=$true)]
    [string]$UserPrincipalName,
    [Parameter(Mandatory=$true)]
    [string]$UpdateType
  )

  Write-SmithsLog -Level DEBUG "[$updateType] [$UserPrincipalName] Set POPEnabled = $($Changes.PopEnabled) IMAPEnabled = $($Changes.ImapEnabled) OWAEnabled = $($Changes.OWAEnabled) ActiveSyncEnabled = $($Changes.ActiveSyncEnabled)"
  If(-not $ReadOnly){
    Set-CASMailbox -Identity $Alias -PopEnabled $Changes.PopEnabled -ImapEnabled $Changes.ImapEnabled -OWAEnabled $Changes.OWAEnabled -ActiveSyncEnabled $Changes.ActiveSyncEnabled
  }

}

Function Set-SmithsExchangeOnlineRole {

  [Cmdletbinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$User,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Role,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [switch]$ReadOnly,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("Add", "Remove")]
    [string]$Action
  )

  Begin {
    $actionMapping = @{
      Add = "Add-RoleGroupMember"
      Remove = "Remove-RoleGroupMember"
    }
    $messageMapping = @{
      Add = "Adding Exchange Online Cloud Admin '{0}' to '{1}' role"
      Remove = "Removing Exchange Online Cloud Admin '{0}' from '{1}' role"
    }
  }
  Process {
    $exchangeOnlineUser = Get-User -Identity $User -ErrorAction SilentlyContinue
    If($?){
      Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Activity "Exchange Online Admin Roles" -Message ($messageMapping.$Action -f $User, $Role)
      $arglist = @{
        "-Identity" = $Role
        "-Member" = $User
        "-ErrorAction" = "SilentlyContinue"
        "-Confirm" = $false
      }
      If(-not $ReadOnly){
        & $actionMapping.$Action @arglist
        If(-not $?){
          Write-SmithsLog -Level ERROR -Identity $User.SamAccountName -Activity "Exchange Online Admin Roles" -Message $error[0].Exception.Message
        }
      }
    }
    Else {
      Write-SmithsLog -Level ERROR -Identity $User.SamAccountName -Activity "Exchange Online Admin Roles" -Message $error[0].Exception.Message
    }
  }
  End {
  }
}
