[CmdletBinding()]
Param()

$script:activity = "Routing Errors"

Function Format-RoutingError {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser]$User,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Configuration,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Issue,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Resolution
  )

  Begin {
  }

  Process {
    [PSCustomObject]@{
      Username = $User.SamAccountName
      Name = $User.Name
      EmailAddress = $User.mail
      Configuration = $Configuration
      Error = $Issue
      Resolution = $Resolution
    }
  }

  End {
  }
}

Function Get-Data {

  [CmdletBinding()]
  Param(
    [Hashtable[]]$DataSets
  )

  $migratingUsersGroup = (Get-ADGroup "BIS O365 Migrating Users").DistinguishedName
  $mailboxes = $DataSets.ExchangeOnline | Select -ExpandProperty PrimarySmtpAddress
  $tests = @(
    [PSCustomObject]@{
      LogMessage = "Finding migrating users without O365 mailbox"
      WhereClause = { $_.memberOf -contains $migratingUsersGroup -and $_.mail -notin $mailboxes -and $_.extensionAttribute4 -eq $null -and $_.Enabled }
      Configuration = "Staged"
      Issue = "No mailbox in Office 365"
      Resolution = "License user or remove from migrating users"
    }
    [PSCustomObject]@{
      LogMessage = "Finding migrating room/equipment/shared accounts without O365 mailbox"
      WhereClause = { $_.memberOf -contains $migratingUsersGroup -and $_.mail -notin $mailboxes -and $_.extensionAttribute4 -ne $null }
      Configuration = "Staged"
      Issue = "No mailbox in Office 365"
      Resolution = "Add migrate flag or remove from migrating users"
    }
    [PSCustomObject]@{
      LogMessage = "Finding migrated users without O365 mailbox"
      WhereClause = { $_.memberOf -notcontains $migratingUsersGroup -and $_.mail -notin $mailboxes -and $_.extensionAttribute4 -eq $null -and $_.extensionAttribute2 -match "/Migrated" -and $_.Enabled }
      Configuration = "Migrated"
      Issue = "No mailbox in Office 365"
      Resolution = "License user"
    }
    [PSCustomObject]@{
      LogMessage = "Finding migrated room/equipment/shared accounts without O365 mailbox"
      WhereClause = { $_.memberOf -notcontains $migratingUsersGroup -and $_.mail -notin $mailboxes -and $_.extensionAttribute4 -ne $null -and $_.extensionAttribute2 -match "/Migrated" }
      Configuration = "Migrated"
      Issue = "No mailbox in Office 365"
      Resolution = "License user"
    }
    [PSCustomObject]@{
      LogMessage = "Finding on-premises users with routed O365 mailbox"
      WhereClause = { $_.memberOf -notcontains $migratingUsersGroup -and $_.mail -in $mailboxes -and $_.extensionAttribute4 -eq $null -and $_.extensionAttribute2 -match "/On-Premises" -and $_.Enabled }
      Configuration = "On-Premises"
      Issue = "Routed mailbox in Office 365"
      Resolution = "Unlicense user or add to migrating users"
    }
    [PSCustomObject]@{
      LogMessage = "Finding on-premises room/equipment/shared accounts with routed O365 mailbox"
      WhereClause = { $_.memberOf -notcontains $migratingUsersGroup -and $_.mail -in $mailboxes -and $_.extensionAttribute4 -ne $null -and $_.extensionAttribute2 -match "/On-Premises" }
      Configuration = "On-Premises"
      Issue = "Routed mailbox in Office 365"
      Resolution = "Add to migrating users"
    }
  )

  $routingErrors = New-Object System.Collections.ArrayList

  Foreach($test in $tests){

    Write-SmithsLog -Level DEBUG -Activity $script:activity -Message $test.LogMessage
    $testResults = [PSCustomObject[]]($DataSets.AD | Where $test.WhereClause | Format-RoutingError -Configuration $test.Configuration -Issue $test.Issue -Resolution $test.Resolution)
    Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "Found $($testResults.Count) routing errors from this test"
    Foreach($t in $testResults){
      $x = $routingErrors.Add($t)
    }
    $testResults = $null

  }


  Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "Found $($routingErrors.Count) users with routing errors"

  @{
    Filename = "routing-errors.json"
    Data = $routingErrors
  }

}

Function Get-Datasets {

  [CmdletBinding()]
  Param()

  [string[]]@("AD", "ExchangeOnline")
}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  [string[]]@("memberOf", "mail", "extensionAttribute2", "extensionAttribute4", "extensionAttribute7")
}

Function Get-Priority {

  100

}




