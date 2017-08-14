[CmdletBinding()]
Param()

$script:activity = "Address"

$addressFields = [string[]]@("streetAddress", "l", "st", "postalCode", "c")

Function Get-Changes {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [Microsoft.ActiveDirectory.Management.ADUser]$User
  )

  $changes = @{}
  $dnc = Get-DNComponents -DistinguishedName $User.DistinguishedName
  If((Compare-DNSegment -DN $dnc -Segment -6 -Value "^OU=[BCDJMS][A-Za-z0-9]{3}$")){

    # User is in a site code OU

    If($User.c -eq $null){

      Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Activity $script:activity -Message "Country is not set, updating"

      # Country is null, must set it

      $ouName = (Get-DNSegment -DN $dnc -FirstSegment -6 -LastSegment -1) -join ","
      $ou = Get-ADOrganizationalUnit -Identity $ouName -Properties $addressFields

      If(-not (Test-NullOrBlank -Value $ou.c)){

        $changes.c = @{Type = "Set"; Value = $ou.c}

        If($User.streetAddress -eq $null){

          Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Activity $script:activity -Message "Address is not set, updating"

          # Address is also blank, set all the rest of the fields

          Foreach($f in $addressFields[0..($addressFields.Count-2)]){
            $changes.$f = @{Type = "Set"; Value = $ou.$f}
          }
        }
        Else {
          Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Activity $script:activity -Message "Street address field already set, skipping address update"
        }
      }
      Else {
        Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Activity $script:activity -Message "OU country is not set, skipping"
      }
    }
    Else {
      Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Activity $script:activity -Message "Country is already set, skipping address update"
    }

  }
  Else {
    Write-SmithsLog -Level DEBUG -Identity $User.SamAccountName -Activity $script:activity -Message "Not in a site code OU"
  }

  $changes

}

Function Get-Attributes {

  [CmdletBinding()]
  Param()

  # Street, City, State, Zip Code, Country
  $addressFields

}


Function Get-Priority {

  [CmdletBinding()]
  Param()

  10

}
