[CmdletBinding()]
Param()

$script:activity = "Migration Status"

Function Get-Changes {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Object]$ResourceUser,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser]$ADUser
  )


  $division = Get-SmithsUserDivision -User $ADUser
  #Else {
  If(-not ($ADUser.Enabled -or $ADUser.extensionAttribute4 -in @("Room","Equipment","Shared"))){
    Write-SmithsLog -Level DEBUG -Activity $script:activity -Identity $ADUser.SamAccountName -Message "Disabled account that is not an equipment/shared/resource mailbox"
    @{extensionAttribute2 = @{Type = "Clear"}}
  }
  ElseIf($ResourceUser.extensionAttribute9 -ne $null -or $ResourceUser.extensionAttribute13 -ne $null){
    Write-SmithsLog -Level DEBUG -Activity $script:activity -Identity $ADUser.SamAccountName -Message "Account that is either staged or migrated"
    If($ResourceUser.extensionAttribute9 -ne $null){
      $status, $datestr = $ResourceUser.extensionAttribute9 -split " "
      If($status -eq "Delta"){
        $status = "Staged"
      }
    }
    If($ResourceUser.extensionAttribute13 -ne $null){
      $status = $ResourceUser.extensionAttribute13 -replace "Completed", "Migrated"
    }

    $attr2 = "$division/$status"
    @{extensionAttribute2 = @{Type = "Replace"; Value = $attr2}}
  }
  ElseIf($ADuser.mail -ne $null){
    $attr2 = "$division/On-Premises"
    Write-SmithsLog -Level DEBUG -Activity $script:activity -Identity $ADUser.SamAccountName -Message "Account that is on-premises"
    @{extensionAttribute2 = @{Type = "Replace"; Value = $attr2}}
  }
  Else {
    Write-SmithsLog -Level ERROR -Activity $script:activity -Identity $ADUser.SamAccountName -Message "Something went wrong, smithsnet mail field is blank but mail field exists"
    @{extensionAttribute2 = @{Type = "Clear"}}
  }
  #}
}

Function Get-ADAttributes {

  [CmdletBinding()]
  Param()

  [string[]]@(
    "extensionAttribute2",
    "division",
    "mail",
    "extensionAttribute4"
  )

}

Function Get-ResourceAttributes {

  [CmdletBinding()]
  Param()

  [string[]]@(
    "mail",
    "samaccountname",
    "extensionAttribute9",
    "extensionAttribute13",
    "msExchMasterAccountSid"
  )
}

Function Get-Priority {

  [CmdletBinding()]
  Param()

  10

}



