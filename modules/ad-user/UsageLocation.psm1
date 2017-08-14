[CmdletBinding()]
Param()

$script:activity = "Usage Location"


Function Get-Changes {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser]$User
  )

  If($User.Country -eq $null -or $User.Country -eq ""){
    Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Message "country is not set or blank, skipping" -Activity $script:activity
  }
  Else {
    Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Message "set usage location = '$($User.Country)'" -Activity $script:activity
    @{msExchUsageLocation = @{Type = "Set"; Value = $User.Country}}
  }

}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  @("Country", "msExchUsageLocation")

}

Function Get-Priority {

  [CmdletBinding()]
  Param()

  20

}
