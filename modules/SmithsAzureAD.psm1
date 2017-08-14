[CmdletBinding()]
Param()

Function Connect-SmithsAAD {

  [CmdletBinding()]
  Param()

  try {
    $credential = Get-SmithsConfigSetting -Component "Office 365" -Name "Credential"
    Write-SmithsLog -Level DEBUG -Activity "Connect" -Identity $credential.Username -Message "Connecting to Azure AD"
    Connect-AzureAD -Credential $credential -ErrorAction Stop
    $alldomains = Get-AzureADDomain
    $script:domains = [string[]]($alldomains | Where { -not $_.IsInitial } | Select -ExpandProperty Name)
    $script:defaultdomain = ($alldomains | Where { $_.IsInitial }).Name
    Write-SmithsLog -Level DEBUG -Activity "Connect" -Identity $credential.Username -Message "Connected to Azure AD for $($script:defaultdomain), $($script:domains.Count) domains found"
  }
  catch {
    Write-SmithsLog -Level FATAL -Activity "Connect" -Identity $credential.Username -Message "Unable to connect to Azure AD: $($_.Exception.Message)"
    Exit 1
  }

}

Function Get-SmithsAADUser {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalName
  )

  Begin {
  }

  Process {
    Try {
      Get-AzureADUser -ObjectId $UserPrincipalName -ErrorAction Stop
    }
    Catch {
      $null
    }
  }

  End {
  }

}

Function Get-SmithsAADDomains {

  [CmdletBinding()]
  Param()

  Get-AzureADDomain | Sort Name

}

Function Find-SmithsAADUsers {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$SearchString
  )

  Try {
    Get-AzureADUser -SearchString $SearchString -ErrorAction Stop -All
  }
  Catch {
    $null
  }

}

Function Test-SmithsAADAddress {

  [CmdletBinding()]
  Param($Address)

  $user,$domain = $Address -split "@"
  $domain -in $script:domains
}

Function Update-SmithsAADUserPrincipalName {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$True, ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser]$user
  )

  Begin {

  }

  Process {

    $userPrincipalName = $user.UserPrincipalName
    If($userPrincipalName -ne $null -and $userPrincipalName -ne "" -and $user.adminDescription -ne "User_DoNotSyncO365"){
      $cloudAnchor = Get-SmithsADUserCloudAnchor -User $user

      # Find the AAD user with matching Cloud Anchor
      $aadUser = Get-AzureADUser -Filter "ImmutableId eq '$cloudAnchor'"
      If($aadUser -ne $null){
        If($aadUser.UserPrincipalName -ne $userPrincipalName){
          $tempUPN = "$($user.SamAccountName)@$($script:defaultdomain)"
          Write-SmithsLog -Level DEBUG -Activity "UPN Update" -Message "Updating UserPrincipalName from '$($aadUser.UserPrincipalName)' to '$UserPrincipalName'"
          If(-not $ReadOnly){

            # this function does output a password if the destination domain is not federated, so capture it just in case
            Try {
              # If the UPN is already an *.onmicrosoft.com UPN, skip the first stage 
              If($tempUPN -ne $aadUser.UserPrincipalName){
                $pwprofile = Get-SmithsAADRandomPasswordProfile
                Write-SmithsLog -Level DEBUG -Activity "UPN Update" -Identity $user.SamAccountName -Message "Updating UserPrincipalName to temp UPN '$tempUPN'"
                Set-AzureADUser -ObjectId $aadUser.ObjectId -UserPrincipalName $tempUPN -PasswordProfile $pwprofile -ErrorAction Stop
                Write-SmithsLog -Level DEBUG -Activity "UPN Update" -Message "Temp UPN '$tempUPN' set"
              }
              Write-SmithsLog -Level DEBUG -Activity "UPN Update" -Identity $user.SamAccountName -Message "Updating UserPrincipalName to final UPN '$userPrincipalName'"
              Set-AzureADUser -ObjectId $aadUser.ObjectId -UserPrincipalName $userPrincipalName -ErrorAction Stop
              Write-SmithsLog -Level DEBUG -Activity "UPN Update" -Identity $user.SamAccountName -Message "Successfully updated UserPrincipalName from '$($aadUser.UserPrincipalName)' to '$UserPrincipalName'"
              $aadUser = Get-AzureADUser -ObjectId $aadUser.ObjectId
            }
            Catch {
              Write-SmithsLog -Level ERROR -Activity "UPN Update" -Identity $user.SamAccountName -Message $_.Exception.Message
              # Try and revert the change back to the original UPN
              Set-AzureADUser -ObjectId $aadUser.ObjectId -UserPrincipalName $aadUser.UserPrincipalName -ErrorAction Stop
            }
          }
        } # End if UPNs do not match
      } # aadUser is not null
      Else {

        # Assume some sort of dirsync error because we can't find the source anchor in O365

        Write-SmithsLog -Level ERROR -Activity "UPN Update" -Identity $user.SamAccountName -Message "Unable to find Azure AD user, check Azure AD Connect for sync errors"
      }

      # Return user, found (and updated if needed) or $null if not

      $aadUser
    }
    ElseIf($User.adminDescription -ne "User_DoNotSyncO365"){
      Write-SmithsLog -Level ERROR -Activity "UPN Update" -Identity $user.SamAccountName -Message "AD UPN is null or blank"
    }
  }

  End {
  }
}

Function New-SmithsAADCloudAdmin {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser]$User,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [PSCredential]$Credential,
    [switch]$ReadOnly
  )

  Begin {
    $upnDomain = $defaultDomain
    (Get-MsolDomain | Where { $_.IsDefault }).Name
    $message = Get-SmithsConfigSetting -Component "Office 365" -Name "New Cloud Admin Message"
    $from = Get-SmithsConfigSetting -Component "Global" -Name "E-mail From"
    $smtpserver = Get-SmithsConfigSetting -Component "Global" -Name "SMTP Server"
  }

  Process {

    $upnStem = $User.SamAccountName.ToLower()
    $firstName = $User.GivenName
    $lastName = $User.Surname
    $newUpn = "$upnStem-ca@$upnDomain"

    Try {
      Write-SmithsLog -Level DEBUG -Activity "Creating O365 User" -Identity $User.SamAccountName -Message "Creating Office 365 cloud admin user '$newUpn'"
      If(-not $ReadOnly){
        $passwordProfile = Get-SmithsAADRandomPasswordProfile -EnforceChangePasswordPolicy:$false
        $newUser = New-AzureADUser -DisplayName "$firstName $lastName (Cloud Admin)" -GivenName $firstName -Surname $lastName -UsageLocation $User.msExchUsageLocation -UserPrincipalName $newUpn -PasswordProfile $passwordProfile
        $User | Set-ADUser -Replace @{extensionAttribute1=$newUpn} -Credential $Credential
      }
      Write-SmithsLog -Level DEBUG -Activity "Creating O365 User" -Identity $User.SamAccountName -Message "Enabling Multi-Factor Authentication"
      If(-not $ReadOnly){
        $auth = New-Object Microsoft.Online.Administration.StrongAuthenticationRequirement
        $auth.RelyingParty = "*"
        $auth.State = "Enabled"
        $auth.RememberDevicesNotIssuedBefore = Get-Date
        Set-MsolUser -UserPrincipalName $newUpn -StrongAuthenticationRequirements $auth
        Write-SmithsLog -Level DEBUG -Activity "Creating O365 User" -Identity $User.SamAccountName -Message "Sending e-mail notification to '$($User.Mail)'"
        Send-MailMessage -To $User.Mail -Bcc $from -Subject "New Office 365 Admin Account Details" -From $from -SmtpServer $smtpserver -Body ($message -replace "{username}", $newUser.UserPrincipalName -replace "{password}", $newUser.Password)
      }
    }
    Catch {
      Write-SmithsLog -Level ERROR -Activity "Creating O365 User" -Identity $User.SamAccountName -Message $_.Exception.Message
      $null
    }
  }

  End {
  }
}

Function Remove-SmithsAADCloudAdmin {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser]$User,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [PSCredential]$Credential,
    [switch]$ReadOnly
  )

  Begin {
  }

  Process {
    Write-SmithsLog -Level DEBUG -Activity "Removing Azure User" -Identity $User.SamAccountName -Message "Removing Azure AD cloud admin account '$($user.extensionAttribute1)'"
    Try {
      If(-not $ReadOnly){
        Remove-AzureADUser -ObjectId $User.extensionAttribute1
        $User | Set-ADUser -Clear extensionAttribute1 -Credential $credential

      }
    }
    Catch {
      Write-SmithsLog -Level ERROR -Activity "Removing Azure AD User" -Identity $User.SamAccountName -Message $_.Exception.Message
    }
  }

  End {
  }
}

<#
Function Set-SmithsAADRoleMember {

  [Cmdletbinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [Object]$User,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Object]$Role,
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
      Add = "Add-MsolRoleMember"
      Remove = "Remove-MsolRoleMember"
    }
    $messageMapping = @{
      Add = "Adding Cloud Admin '{0}' to '{1}' role"
      Remove = "Removing Cloud Admin '{0}' from '{1}' role"
    }
  }
  Process {
    Try {
      $msolUser = Get-MsolUser -ObjectId $User.ObjectId -ErrorAction SilentlyContinue
      Write-SmithsLog -Level DEBUG -Identity $User.UserPrincipalName -Activity "Office 365 Admin Roles" -Message ($messageMapping.$Action -f $User.UserPrincipalName, $Role.Name)
      $arglist = @{
        "-RoleObjectId" = $Role.ObjectId
        "-RoleMemberType" = "User"
        "-RoleMemberObjectId" = $User.ObjectId
        "-ErrorAction" = "Stop"
      }
      If(-not $ReadOnly){
        & $actionMapping.$Action @arglist
      }
    }
    Catch {
      Write-SmithsLog -Level ERROR -Identity $User.UserPrincipalName -Activity "Office 365 Admin Roles" -Message $_Exception.Message
    }
  }
  End {
  }
}
#>

Function Get-SmithsAADRandomPasswordProfile {

  [CmdletBinding()]
  Param(
    [switch]$EnforceChangePasswordPolicy
  )

  $profile = New-Object Microsoft.Open.AzureAD.Model.PasswordProfile
  $profile.Password = Get-SmithsRandomPassword
  $profile.ForceChangePasswordNextLogin = $true
  $profile.EnforceChangePasswordPolicy = $EnforceChangePasswordPolicy

  $profile

}
