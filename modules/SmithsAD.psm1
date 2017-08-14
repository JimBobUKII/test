<#
.SYNOPSIS
    Sets the adminDescription flag for users that should not be synced to Azure AD.
.DESCRIPTION
    Scans AD for users and groups that do not have an exclusion flag in place. Sets
    the flag for any users that are located outside of a standard users OU.
.NOTES
    Author: David Gee

    Version History:
    Version   Date        Author                Changes
    1.0       09/09/2016  David Gee             Initial release
#>

$validDivisions = Get-SmithsConfigSetting -Component "Active Directory" -Name "Divisions"
Set-Variable -Name "NOT_PRESENT" -Value "<Not Present>" -Option Constant


Function Compare-DNSegment {

  [CmdletBinding()]
  Param(
    [Parameter(ParameterSetName="SingleValue")]
    [Parameter(ParameterSetName="MultiValue")]
    [string[]]$DN,
    [Parameter(ParameterSetName="SingleValue")]
    [Parameter(ParameterSetName="MultiValue")]
    [int]$Segment,
    [Parameter(ParameterSetName="SingleValue")]
    [string]$Value,
    [Parameter(ParameterSetName="MultiValue")]
    [string[]]$Values
  )


  If($Segment -lt 0){
    $Segment = $DN.Length + $Segment
  }

  $base = $False
  Switch($PSCmdlet.ParameterSetName){
    "MultiValue" {
      # array, process each
      Foreach($val in $Values){
        $base = $base -or ((Get-DNSegment -DN $DN -Segment $Segment) -match $val)
      }
    }
    "SingleValue" {
      # single value
      $base = (Get-DNSegment -DN $DN -Segment $Segment) -match $Value
    }
  }

  $base

}

Function Get-DNSegment {

  [CmdletBinding()]
  Param(
    [Parameter(ParameterSetName="SingleValue")]
    [Parameter(ParameterSetName="MultiValue")]
    [string[]]$DN,
    [Parameter(ParameterSetName="SingleValue")]
    [int]$Segment,
    [Parameter(ParameterSetName="MultiValue")]
    [int]$FirstSegment,
    [Parameter(ParameterSetName="MultiValue")]
    [int]$LastSegment

  )


  Switch($PSCmdlet.ParameterSetName){
    "MultiValue" {
      If($FirstSegment -lt 0){
        $FirstSegment = $DN.Length + $FirstSegment
      }
      If($LastSegment -lt 0){
        $LastSegment = $DN.Length + $LastSegment
      }
      Try {
        $DN[$FirstSegment..$LastSegment]
      }
      Catch {
        $null
      }
    }
    "SingleValue" {
      # single value
      If($Segment -lt 0){
        $Segment = $DN.Length + $Segment
      }
      Try {
        $DN[$Segment]
      }
      Catch {
        $null
      }
    }
  }


}

Function Get-DNComponents {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $DistinguishedName
  )

  $DistinguishedName -split "(?<!\\),"

}

Function Get-FieldDisplayValue {

  [CmdletBinding()]
  Param(
    $Value
  )


  If($Value -ne $null){
    If($Value.Count -gt 0){
      $Value -join ";"
    }
    Else {
      $Value
    }
  }
  Else {
    $NOT_PRESENT
  }

}

Function Get-UpdateParams {

  [CmdletBinding()]
  Param(
    [System.Collections.Hashtable]$Changes,
    [Microsoft.ActiveDirectory.Management.ADPrincipal]$Object
  )

  $Add = @{}
  $Replace = @{}
  $Remove = @{}
  $Clear = @()

  $UpdateParams = @{}
  $DebugMessages = @()

  Foreach($change in $Changes.GetEnumerator()){

    $field = $change.Name
    $changeType = $change.Value.Type
    $value = $change.Value.Value

    $displayValue = Get-FieldDisplayValue -Value $value
    $displayPreviousValue = Get-FieldDisplayValue -Value $Object.$field
    If($value -eq $null -or $value.Count -eq 1){
      $expandedValue = $value
    }
    Else {
      $expandedValue = ($value | Sort-Object -CaseSensitive) -join " -- "
    }
    If($Object.$field -eq $null -or $Object.$field.Count -eq 1){
      $expandedPreviousValue = $Object.$field
    }
    Else {
      $expandedPreviousValue = ($Object.$field | Sort-Object -CaseSensitive) -join " -- "
    }
    Switch($changeType){
      "Add" {
        $DebugMessages += "${changeType}: $field = '$displayValue', previous value = '$displayPreviousValue'"
        $Add.$field = $value
      }
      "Replace" {
        If(Test-NullOrBlank -Value $value){
          # Don't need to clear if already null
          If($expandedValue -cne $expandedPreviousValue){
            $DebugMessages += "Clear: $field, previous value = '$displayPreviousValue'"
            $Clear += $field
          }
          Else {
            $DebugMessages += "${changeType}: $field already unset, skipping"
          }
        }
        ElseIf($expandedValue -cne $expandedPreviousValue){
          # Only set if different to current value
          $DebugMessages += "${changeType}: $field = '$displayValue', previous value = '$displayPreviousValue'"
          $Replace.$field = $value
        }
        Else {
          $DebugMessages += "${changeType}: $field already set to '$expandedPreviousValue', skipping"
        }
      }
      "Remove" {
        $Remove.$field = $value
        $DebugMessages += "${changeType}: $field = '$displayValue', previous value = '$displayPreviousValue'"
      }
      "Clear" {
        If((Test-NullOrBlank -Value $expandedPreviousValue) -or ($displayPreviousValue -eq $NOT_PRESENT)){
          $DebugMessages += "${changeType}: $field already unset, skipping"
        }
        Else {
          $DebugMessages += "${changeType}: $field, previous value = '$displayPreviousValue'"
          $Clear += $field
        }
      }
      "Set" {
        # Set does the same as "Add" if no value exists, or "Replace" if a value exists
        If(Test-NullOrBlank -Value $value){
          If($Object.$field -cnotin @("", $null)){
            $DebugMessages += "Clear: $field, previous value = '$displayPreviousValue'"
            $Clear += $field
          }
          Else {
            $DebugMessages += "${changeType}: $field already unset, skipping"
          }
        }
        ElseIf($Object.$field -ne $null){
          # Replace
          If($expandedValue -cne $expandedPreviousValue){
            # Only set if different to current value
            $DebugMessages += "Replace: $field = '$displayValue', previous value = '$displayPreviousValue'"
            $Replace.$field = $value
          }
          Else {
            $DebugMessages += "${changeType}: $field already set to '$expandedPreviousValue', skipping"
          }
        }
        Else {
          $DebugMessages += "Add: $field = '$displayValue', previous value = '$displayPreviousValue'"
          $Add.$field = $value
        }
      }
      default {
        Write-Host "invalid changeType $changeType"
      }
    }

  }
  If($Add.Count -gt 0){ $UpdateParams["-Add"] = $Add}
  If($Replace.Count -gt 0){ $UpdateParams["-Replace"] = $Replace}
  If($Remove.Count -gt 0){ $UpdateParams["-Remove"] = $Remove}
  If($Clear.Count -gt 0){ $UpdateParams["-Clear"] = $Clear}

  $UpdateParams, $DebugMessages

}


Function Set-SmithsADObject {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Identity,
    [Parameter(Mandatory=$true)]
    [ValidateSet("USER", "GROUP")]
    [string]$ObjectType,
    [Parameter(Mandatory=$true)]
    [System.Collections.Hashtable]$Changes,
    [Parameter(Mandatory=$true)]
    [PSCredential]$Credential,
    [switch]$ReadOnly,
    [Parameter(Mandatory=$true)]
    [Object]$Object
  )


  switch($ObjectType){
    "USER" {
      $activity = "Update User"
      $setCommand = "Set-ADUser"
    }
    "GROUP" {
      $activity = "Update Group"
      $setCommand = "Set-ADGroup"
    }
  }
  $success = 0
  $failure = 0
  $skip = 0

  $logParams = @{
    Identity = $Identity
    Activity = $activity
  }

  If($ReadOnly){
    $logParams.Activity += " Simulation"
  }

  # Updates to group membership must be handled via Add/Remove-GroupMember

  If("memberOf" -in $Changes.Keys -and $ObjectType -eq "USER"){
    $memberOf = $Changes.memberOf
    $memberOfType = $memberOf.Type
    $memberOfValue = $memberOf.Value
    $groupCommand = @{
      Add = @("Add-ADGroupMember", "to")
      Remove = @("Remove-ADGroupMember", "from")
    }
    Foreach($m in $memberOfValue){
      $cmd, $tofrom = $groupCommand.$memberOfType
      Write-SmithsLog -Level DEBUG -Message "$memberOfType $tofrom group $m" @logParams
      If(-not $ReadOnly){
        & $cmd -Identity $m -Members $Object -Credential $credential -Confirm:$false
        $success = 1
      }
    }
    $Changes.Remove("memberOf")
  }
  $UpdateParams, $DebugMessages = Get-UpdateParams -Changes $Changes -Object $Object
  Foreach($m in $DebugMessages){
    Write-SmithsLog -Level DEBUG -Message $m @logParams
  }

  If($UpdateParams.Keys.Count -gt 0){
    $UpdateParams["-Identity"] = $Identity
    $UpdateParams["-Credential"] = $Credential
    $UpdateParams["-ErrorAction"] = "Stop"
    Write-SmithsLog -Level DEBUG -Message "writing changes to AD" @logParams

    Try {
      If(-not $ReadOnly){
        & $setCommand @UpdateParams
      }
      $success = 1
    }
    Catch {
      $failure = 1
      Write-SmithsLog -Level ERROR -Message $_.Exception.Message @logParams
    }
  }
  Else {
    $skip = 1
    Write-SmithsLog -Level DEBUG -Message "no changes needed, skipping" @logParams
  }
  # Return the three values
  $success, $failure, $skip
}

Function Get-SmithsADLDAPFilter {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("USER", "GROUP")]
    [ValidateNotNullOrEmpty()]
    [string]$ObjectType,
    [switch]$UpdateAll,
    [switch]$TestUsers,
    [switch]$TestGroups,
    [string]$CustomFilter,
    [switch]$ForCloud,
    [string]$LastRun,
    [string[]]$AdditionalFilter
  )

  $filterStack = @()

  Switch($ObjectType){
    "USER" {
      $filterStack += Get-SmithsADLDAPUserFilter
    }
    "GROUP" {
      $filterStack += Get-SmithsADLDAPGroupFilter
    }
  }
  If(-not $UpdateAll){
    $delta = Get-SmithsConfigSetting -Component "Active Directory" -Name "Update Delta"
    Try {
      [DateTime]$LastRunStamp = [DateTime]$LastRun
    }
    Catch {
      [DateTime]$LastRunStamp = (Get-Date).AddMinutes(-30)
    }
    $datestring = $LastRunStamp.AddMinutes(0 - $delta).ToString("yyyyMMddHHmmss.0Z")
    $filterStack += "(whenChanged>=$datestring)"
  }
  If($TestUsers){
    $testusernames = Get-SmithsConfigSetting -Component "Active Directory" -Name "Test Users"
    $filterStack += Get-SmithsADCombinedLDAPFilter -Attribute "sAMAccountName" -Operator "OR" -Values $testusernames
  }
  If($TestGroups){
    $testgroupnames = Get-SmithsConfigSetting -Component "Active Directory" -Name "Test Groups"
    $filterStack += Get-SmithsADCombinedLDAPFilter -Attribute "sAMAccountName" -Operator "OR" -Values $testgroupnames
  }
  If($CustomFilter -ne $null -and $CustomFilter -ne ""){
    $filterStack += $CustomFilter
  }
  If($ForCloud){
    $filterStack += "(!(adminDescription=User_DoNotSyncO365))"
    $filterStack += "(userPrincipalName=*)"
  }
  Foreach($f in $AdditionalFilter){
    $filterStack += $f
  }
  $combinedFilters = $filterStack -join ""
  $finalFilter = "(&$combinedFilters)"
  Write-SmithsLog -Level DEBUG -Activity "AD Search" -Message "LDAP Filter: $finalFilter"
  $finalFilter

}

Function Get-SmithsADCombinedLDAPFilter {

  [CmdletBinding()]
  Param(
    [string]$Attribute,
    [Parameter(Mandatory=$True)]
    [ValidateSet("AND", "OR")]
    [ValidateNotNullOrEmpty()]
    [string]$Operator,
    [string[]]$Values
  )

  $op = @{
    AND = "&"
    OR = "|"
  }

  $filter = "($($op.$Operator)"
  Foreach($value in $Values){
    $filter += "($Attribute=$value)"
  }
  $filter += ")"
  $filter
}

Function Get-SmithsADLDAPUserFilter {

  $samAccountType= 0x30000000

  "(sAMAccountType=$sAMAccounttype)"

}

Function Get-SmithsADLDAPGroupFilter {

  Get-SmithsADCombinedLDAPFilter -Attribute "sAMAccountType" -Operator "OR" -Values @(
    0x10000000 # Global/universal security group
    0x10000001 # Global/universal distribution list
    0x20000000 # Domain local security group
    0x20000001 # Domain local distribution list
  )
}

Function Get-SmithsADGroupMember {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({$_ -match "^CN="})]
    [string]$Identity,
    [string]$Filter = "",
    [string[]]$Properties = @()
  )

  Begin {
    $props = @{}
    If($Filter -ne ""){
      $addlFilt = "($Filter)"
    }
    Else {
      $addlFilt = ""
    }
    If($Properties.Count -gt 0){
      $props."-Properties" = $Properties
    }
  }

  Process {
    Get-ADUser -LDAPFilter "(&$($addlFilt)(memberOf=$Identity)(!(adminDescription=User_*)))" @props
  }

  End {
  }

}

Function Get-SmithsADClientStatusData {

  [CmdletBinding()]
  Param()

  $rawdata = Import-Csv -Path "$smithsroot/data/dpstatus.csv"

  $statuses = @{}
  $customorder = @{
    NotInstalled = 0
    Installing = 1
    Installed = 2
    Running = 3
    Failed = 4
    Complete = 5
  }
  $mappings = @{
    NotInstalled = "Scheduled"
    Installing = "Installing"
    Installed = "Pending Start"
    Running = "Running"
    Failed = "Failed"
    Complete = "Complete"
  }

  $users = $rawdata | Group-Object PrimaryEmailAddress
  Foreach($u in $users){
    $statuses[$u.Name] = $u.Group | Sort-Object -Property @{Expression={ Try { $customorder[$_.DPStatus] } Catch { -1 }}} | Select -Last 1 @{Label="ClientStatus";Expression={$mappings[$_.DPStatus]}} | Select -ExpandProperty ClientStatus
  }

  $statuses

}

Function Get-SmithsADMigrationSummary {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [Microsoft.ActiveDirectory.Management.ADUser]$User,
    [String[]]$Attributes#,
    #[Hashtable]$ClientData
  )

  Begin {
  }

  Process {
    If($User.Enabled -or $User.extensionAttribute4 -ne $null){
      $obj = @{
        User = $User.Name
        Username = $User.SamAccountName
        Division = "Unknown"
        Status = "On-Premises"
        MailboxType = "User Mailbox"
        ClientStatus = "Not Started"
        CombinedStatus = "On-Premises"
        Country = $User.Country
      }
      Foreach($a in $attributes){
        $obj.$a = $User.$a
      }
      If($User.extensionAttribute4 -ne $null){
        $obj.MailboxType = $User.extensionAttribute4 + " Mailbox"
      }
      If($User.Contains("extensionAttribute2")){
        $division,$status = $User.extensionAttribute2 -split "/"
        $obj.Division = $division
        $obj.Status = $status
        If($obj.Status -match "^Migrated"){
          $obj.CombinedStatus = "Migrated"
        }
        <#If($obj.Status -match "^Migrated"){
          $obj.CombinedStatus = "Completed"
          If($User.mail -in $ClientData.Keys){
            $clientstatus = $ClientData[$User.mail]

            $obj.ClientStatus = $clientstatus
            If($clientstatus -in @("Running", "Failed", "Complete")){
              $obj.CombinedStatus = $clientstatus
            }
          }
        }#>

      }
      [PSCustomObject]$Obj
    }
  }

  End {
  }
}

Function Get-SmithsDivisionFromDN {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [String]$DistinguishedName
  )

  $dnc = Get-DNComponents -DistinguishedName $DistinguishedName
  $dnc[-5].Substring(3) -replace "Central", "Corporate"

}

Function Get-SmithsDivisionFromOU {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [String]$OU
  )

  Try {
    $orgUnit = Get-ADOrganizationalUnit -LDAPFilter "(OU=$OU)"
    $division = Get-SmithsDivisionFromDN -DistinguishedName $orgUnit.DistinguishedName
  }
  Catch {
    # No OU with that name
  }
  $division
}

Function Get-SmithsUserDivision {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser]$User
  )

  If($User.division -ne $null -and $User.division -in $validDivisions){
    $division = $User.division
    $method = "division field"
  }
  ElseIf(($dndiv = Get-SmithsDivisionFromDN -DistinguishedName $User.DistinguishedName) -in $validDivisions){
    $division = $dndiv
    $method = "user DN"
  }
  ElseIf(($oudiv = Get-SmithsDivisionFromOU -OU $User.SamAccountName.Substring(0, 4)) -in $validDivisions){
    $division = $oudiv
    $method = "username"
  }
  Else {
    $division = "Unknown"
    $method = "unknown"
  }
  Write-SmithsLog -Level DEBUG -Activity "Find division" -Identity $User.SamAccountName -Message "Found division $division with $method"
  $division
}

Function Get-SmithsADUserCloudAnchor {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [Microsoft.ActiveDirectory.Management.ADUser]$User
  )

  [Convert]::ToBase64String($user.ObjectGUID.ToByteArray())
}
