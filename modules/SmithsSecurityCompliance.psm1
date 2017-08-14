Function Connect-SmithsSecurityCompliance {

  [CmdletBinding()]
  Param()

  $credential = Get-SmithsConfigSetting -Component "Office 365" -Name "Credential"
  Write-SmithsLog -Level DEBUG -Activity "Connect" -Identity $credential.Username -Message "Connecting to Security and Compliance PowerShell"
  $script:session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://ps.compliance.protection.outlook.com/powershell-liveid/" -Credential $credential -Authentication Basic -AllowRedirection
  $script:module = Import-PSSession -Session $session -AllowClobber -Prefix "SC_Unused"
  Import-Module $script:module -Global -WarningAction SilentlyContinue -Prefix "SC"

  Write-SmithsLog -Level DEBUG -Activity "Connect" -Identity $credential.Username -Message "Connected to Security and Compliance PowerShell"
}

Function Disconnect-SmithsSecurityCompliance {

  [CmdletBinding()]
  Param()

  Remove-PSSession $script:session
  Remove-Module $script:module

}


Function Set-SmithsSecurityComplianceRole {

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
      Add = "Add-SCRoleGroupMember"
      Remove = "Remove-SCRoleGroupMember"
    }
    $messageMapping = @{
      Add = "Adding Security & Compliance Cloud Admin '{0}' to '{1}' role"
      Remove = "Removing Security & Compliance Cloud Admin '{0}' from '{1}' role"
    }
  }
  Process {
    $scUser = Get-SCUser -Identity $User -ErrorAction SilentlyContinue
    If($?){
      Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Activity "Security and Compliance Admin Roles" -Message ($messageMapping.$Action -f $User, $Role)
      $arglist = @{
        "-Identity" = $Role
        "-Member" = $User
        "-ErrorAction" = "SilentlyContinue"
        "-Confirm" = $false
      }
      If(-not $ReadOnly){
        & $actionMapping.$Action @arglist
        If(-not $?){
          Write-SmithsLog -Level ERROR -Identity $User.SamAccountName -Activity "Security and Compliance Admin Roles" -Message $error[0].Exception.Message
        }
      }
    }
    Else {
      Write-SmithsLog -Level ERROR -Identity $User.SamAccountName -Activity "Security and Compliance Admin Roles" -Message $error[0].Exception.Message
    }
  }
  End {
  }
}
