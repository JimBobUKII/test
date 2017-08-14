[CmdletBinding()]
Param()

Function Connect-SmithsO365 {

  [CmdletBinding()]
  Param()

  try {
    $credential = Get-SmithsConfigSetting -Component "Office 365" -Name "Credential"
    Write-SmithsLog -Level DEBUG -Activity "Connect" -Identity $credential.Username -Message "Connecting to Office 365"
    Connect-MsolService -Credential $credential -ErrorAction Stop
    Write-SmithsLog -Level DEBUG -Activity "Connect" -Identity $credential.Username -Message "Connected to Office 365"
  }
  catch {
    Write-SmithsLog -Level FATAL -Activity "Connect" -Identity $credential.Username -Message "Unable to connect to Office 365: $($_.Exception.Message)"
    Exit 1
  }

}

Function Get-SmithsO365User {

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
      Get-MsolUser -UserPrincipalName $UserPrincipalName -ErrorAction Stop
    }
    Catch {
      $null
    }
  }

  End {
  }

}

Function Find-SmithsO365Users {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$SearchString
  )

  Try {
    Get-MsolUser -SearchString $SearchString -Synchronized -ErrorAction Stop -All
  }
  Catch {
    $null
  }

}

Function Test-SmithsO365Address {

  [CmdletBinding()]
  Param($Address)

  If($script:o365domains -eq $null){
    $script:o365domains = [string[]](Get-MsolDomain | Select -ExpandProperty Name)
  }
  $user,$domain = $Address -split "@"
  $domain -in $script:o365domains
}

Function Get-SmithsO365UserAndFixUPN {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$True, ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser]$ADUser
  )

  Begin {

    $smithsO365DefaultDomain = (Get-MsolDomain | Where { $_.IsDefault }).Name

    $algorithms = @(
      @{
        Name = "Find by UPN"
        ScriptBlock = {
          Get-SmithsO365User -UserPrincipalName $ADUser.UserPrincipalName
        }
      }
      @{
        Name = "Search by surname"
        ScriptBlock = {
          If($ADUser.Surname -ne $null -and $ADUser.Surname -ne ""){
            Find-SmithsO365Users -SearchString $ADUser.Surname | Where { $_.ImmutableId -eq $sourceAnchor }
          }
        }
      }
      @{
        Name = "Search by first name"
        ScriptBlock = {
          If($ADUser.GivenName -ne $null -and $ADUser.GivenName -ne ""){
            Find-SmithsO365Users -SearchString $ADUser.GivenName | Where { $_.ImmutableId -eq $sourceAnchor }
          }
        }
      }
      @{
        Name = "Search by e-mail"
        ScriptBlock = {
          If($ADUser.mail -ne $null -and $ADUser.mail -ne ""){
            Find-SmithsO365Users -SearchString $ADUser.mail | Where { $_.ImmutableId -eq $sourceAnchor }
          }
        }
      }
      @{
        Name = "Search by username"
        ScriptBlock = {
          Find-SMithsO365Users -SearchString "$($ADUser.SamAccountName)@smiths.net" | Where { $_.ImmutableId -eq $sourceAnchor }
        }
      }
    )
  }

  Process {

    $userPrincipalName = $ADUser.UserPrincipalName
    If($userPrincipalName -ne $null -and $userPrincipalName -ne ""){
      $sourceAnchor = [Convert]::ToBase64String($ADUser.ObjectGUID.ToByteArray())
      $msolUser = $null
      $attempt = 1
      Foreach($algorithm in $algorithms){
        Write-SmithsLog -Level DEBUG -Identity $ADUser.SamAccountName -Activity "Finding O365 User" -Message "Attempt $attempt ($($algorithm.Name))"
        Try {
          $msolUser = Invoke-Command -ScriptBlock $algorithm.ScriptBlock
          If($msolUser -ne $null){
            break
          }
        }
        Catch {
        }
        $attempt++
      }
      If($msolUser -ne $null){
        If($msolUser.UserPrincipalName -ne $ADUser.UserPrincipalName){
          $tempUPN = "$($ADUser.SamAccountName)@$smithsO365DefaultDomain"
          Write-SmithsLog -Level DEBUG -Activity "UPN Update" -Message "Updating UserPrincipalName from '$($msolUser.UserPrincipalName)' to '$UserPrincipalName'"
          If(-not $ReadOnly){

            # this function does output a password if the destination domain is not federated, so capture it just in case
            Try {
              If($tempUPN -ne $msolUser.UserPrincipalName){
                $setUPNOutput = Set-MsolUserPrincipalName -ObjectId $msolUser.ObjectId -NewUserPrincipalName $tempUPN -ErrorAction Stop
              }
              $setUPNOutput = Set-MsolUserPrincipalName -ObjectId $msolUser.ObjectId -NewUserPrincipalName $UserPrincipalName -ErrorAction Stop
              Write-SmithsLog -Level DEBUG -Activity "UPN Update" -Message "Successfully updated UserPrincipalName from '$($msolUser.UserPrincipalName)' to '$UserPrincipalName'"
              $msolUser = Get-SmithsO365User -UserPrincipalName $UserPrincipalName
            }
            Catch {
              Write-SmithsLog -Level ERROR -Activity "UPN Update" -Identity $ADUser.SamAccountName -Message $_.Exception.Message
            }
          }
        } # End if UPNs do not match
      } # msoluser is not null
      Else {

        # Assume some sort of dirsync error because we can't find the source anchor in O365

        Write-SmithsLog -Level ERROR -Activity "UPN Update" -Identity $ADUser.SamAccountName -Message "Unable to find O365 user, check Azure AD Connect for sync errors"
      }

      # Return user, found (and updated if needed) or $null if not

      $msolUser
    }
    Else {
      Write-SmithsLog -Level ERROR -Activity "UPN Update" -Identity $ADUser.SamAccountName -Message "UPN is null or blank"
    }
  }

  End {
  }
}

Function New-SmithsO365CloudAdmin {

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
    $upnDomain = (Get-MsolDomain | Where { $_.IsDefault }).Name
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
        $newUser = New-MsolUser -DisplayName "$firstName $lastName (Cloud Admin)" -FirstName $firstName -LastName $lastName -UsageLocation $User.msExchUsageLocation -UserPrincipalName $newUpn -StrongPasswordRequired $true -ForceChangePassword $true
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

Function Remove-SmithsO365CloudAdmin {

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
    Write-SmithsLog -Level DEBUG -Activity "Removing O365 User" -Identity $User.SamAccountName -Message "Removing Office 365 cloud admin account '$($user.extensionAttribute1)'"
    Try {
      If(-not $ReadOnly){
        Remove-MsolUser -UserPrincipalName $User.extensionAttribute1 -Force
        Remove-MsolUser -UserPrincipalName $User.extensionAttribute1 -Force -RemoveFromRecycleBin
        $User | Set-ADUser -Clear extensionAttribute1 -Credential $credential

      }
    }
    Catch {
      Write-SmithsLog -Level ERROR -Activity "Removing O365 User" -Identity $User.SamAccountName -Message $_.Exception.Message
    }
  }

  End {
  }
}


Function Set-SmithsO365RoleMember {

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
