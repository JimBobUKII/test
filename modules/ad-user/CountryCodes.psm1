[CmdletBinding()]
Param()

$script:activity = "Country codes"

$script:countryData = ([xml](Get-Content -Path "$SmithsRoot/config/countries.xml" -Encoding utf8)).countries.country


Function Get-Changes {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser]$User
  )

  $changes = @{}
  If((Test-NullOrBlank -Value $User.c)){
    Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Activity $script:activity -Message "Country is not set, skipping country code sync"
  }
  Else {
    $country = $script:countryData | Where { $_.c -eq $User.c }
    If($country -eq $null){
      Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Activity $script:activity -Message "Invalid country code set, skipping country code sync"
    }
    Else {
      Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Activity $script:activity -Message "Syncing country code $($User.c): co = '$($country.co)', countryCode = '$($country.countryCode)'"
      $changes.co = @{Type = "Set"; Value = $country.co}
      $changes.countryCode = @{Type = "Set"; Value = $country.countryCode}
    }
  }

  $changes

}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  [string[]]@("c", "co", "countryCode")

}


Function Get-Priority {

  [CmdletBinding()]
  Param()

  120

}
