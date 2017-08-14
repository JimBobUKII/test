[CmdletBinding()]
Param()

Function Get-SmithsScriptRoot {

  [CmdletBinding()]
  Param()

  $scriptPath = Split-Path -Path (Get-PSCallStack | Where { $_.ScriptName -ne $null } | Select -Last 1 -ExpandProperty ScriptName) -Parent

  Set-Variable -Name "smithsroot" -Scope Global -Value (Resolve-Path "$scriptPath/../")
}

Get-SmithsScriptRoot

Function Import-SmithsConfig {

  [CmdletBinding()]
  Param(
    [Hashtable]$Overrides = @{}
  )

  try {

    Set-Variable -Scope Global -Name "o365overrides" -Value $Overrides
    Set-Variable -Scope Global -Name "o365config" -Value ([xml](Get-Content -Path "$smithsroot/config/config.xml"))

  }
  catch {

    Write-SmithsLog -Level FATAL -Activity "Loading config file" -Message "Error reading config file: $($_.Exception.Message)"
    Exit 1

  }
}

Function Get-SmithsConfigAllSettings {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [String]$Component
  )

  $scope = $o365config.config.static.scope | Where { $_.name -eq $Component }
  $settings = @{}

  Foreach($entry in $scope.setting){
    $settings[$entry.Name] = Get-SmithsConfigSetting -Component $Component -Name $entry.Name
  }
  $settings
}

Function Get-SmithsConfigSetting {

  [CmdletBinding()]
  Param(
    [String]$Component = "Global",
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [String]$Name
  )

  $scope = $o365config.config.static.scope | Where { $_.name -eq $Component }
  $entry = $scope.setting | Where { $_.name -eq $Name }
  # Used to use #text, we do this instead now so that #cdata-sections also work
  $text = $entry.InnerText

  If("$Component.$Name" -in $o365overrides.Keys){
    $text = $o365overrides."$Component.$Name"
  }

    try {
      switch($entry.type){
        "boolean" {
          If($text -is [boolean]){
            $text
          }
          Else {
            [Convert]::ToBoolean($text)
          }
        }
        "long" {
          If($text -is [long]){
            $text
          }
          Else {
            [Convert]::ToInt64($text)
          }
        }
        "string[]" {
          # Array of strings - split and return array
          # Comma separated. Backslash is the escape character.

          If($text -is [string[]]){
            $text
          }
          Else {
            $text -split "(?<!\\),"
          }
        }
        "credential" {
          # Value is the name of a file relative to $smithsroot
          # Read and convert to PSCredential object

          If($text -is [PSCredential]){
            $text
          }
          Else {
            Try {
              ($username, $encryptedpw) = (Get-Content "$smithsroot/credentials/$text" -ErrorAction Stop) -split ","

              $ss = $encryptedpw | ConvertTo-SecureString -ErrorAction Stop
              New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @($username, $ss)
            }
            Catch {
              Write-SmithsLog -Level ERROR -Activity "Get Config" -Message "Error reading credential from file, falling back to interactive prompt"
              Get-Credential -Message $Component
            }
          }
        }
        "file" {
          Try {
            Get-Content "$smithsroot/$text" -Raw
          }
          Catch {
            Write-SmithsLog -Level ERROR -Activity "Get Config" -Message $_.Exception.Message
          }
        }
        default {
          # Type string
          $text
        }
      }
    }
    catch {
      Write-SmithsLog -Level WARN -Activity "Get Config" -Message "Error converting value '$($text)' to $($entry.type)"
      $null
    }
}

Function Get-SmithsConfigGroupSetting {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $Component
  )

  $component = $o365config.config.groups.scope | Where { $_.name -eq $component }

  Foreach($x in $component.setting){
    [PSCustomObject]@{
      Name = $x.name
      Description = $x.description
      Type = $x.type
      Include = [string[]]($x.group | Where { $_.type -eq "include" } | Select -ExpandProperty name | Get-ADGroup | Select -ExpandProperty DistinguishedName)
      Exclude = [string[]]($x.group | Where { $_.type -eq "exclude" } | Select -ExpandProperty name | Get-ADGroup | Select -ExpandProperty DistinguishedName)
    }
  }

}

Function Import-SmithsModule {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $Name
  )

  # $PSScriptRoot here is the modules directory
  Import-Module "$PSScriptRoot/$Name" -Force -Scope Global

}

Function Test-SmithsGroupMemberships {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [Object[]]$Groups,
    [string[]]$MemberOf=@()
  )

  Begin {

  }
  Process {
   Foreach($entry in $Groups){
      $isMatch = $True

      # If the include group is not empty and is an array

      If($entry.Include -ne $null -and $entry.Include -is [array]){

        # Check to see whether the user is in any of the included groups

        $m = $MemberOf | Where { $_ -in $entry.Include }

        # If not, then they're not a match

        If($m.Count -eq 0){
          $isMatch = $false
        }
      }

      # If the exclude group is not empty and is an array

      If($entry.Exclude -ne $null -and $entry.exclude -is [array]){

        # Check to see whether the user is in any of the excluded groups

        $m = $MemberOf | Where { $_ -in $entry.Exclude }

        # If so, then they're not a match

        If($m.Count -gt 0){
          $isMatch = $false
        }
      }

      # Finally, return the entry if it's a match

      If($isMatch){
        $entry
      }
    }
  }

  End {
  }

  #$memberships

}


Function Test-NullOrBlank {

  Param(
    [Object]$Value
  )

  If($Value -eq $null){
    $True
  }
  If($Value.Count -ne $null){
    $Value.Count -eq 0
  }
  Else {
    Switch($Value.GetType()){
      [string] {
        $Value -eq $null -or $Value -eq ""
      }
      default {
        $Value -eq $null
      }
    }
  }
}

# set up the random password characters we want to use

$script:passwordchars = 33..126 | Foreach-Object {
  [char][byte]$_
}

Function Get-SmithsRandomPassword {

  Param(
    [int]$Length = 16
  )

  (1..$length | Foreach-Object { $script:passwordchars | Get-Random }) -join ""

}
