[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  $SiteCode, 
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  $City,
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  $CountryCode
)

Function main {

  If($SiteCode -notmatch "^[BCDJMS][A-Z0-9]{3}$"){
    throw "Invalid site code '$SiteCode'."
  }

  If($CountryCode -notmatch "^[A-Z]{2}$"){
    throw "Invalid country code '$CountryCode'"
  }

  $sessions = [System.Management.Automation.Runspaces.PSSession[]](Get-PSSession  | Where { $_.ComputerName -eq "outlook.office365.com" -and $_.State -eq "Opened" })

  If($sessions.Count -eq 0){
    throw "Please connect to Exchange Online remote PowerShell and try again."
  }

  $al = [Object[]](Get-AddressList | Where { $_.DisplayName -match "^$SiteCode" })

  If($al.Count -ne 0){
    throw "An address list for site '$siteCode' already exists."
  }
  
  Write-Host "Creating address list '$SiteCode - $City, $CountryCode'"

  New-AddressList -Name "$SiteCode - $City, $CountryCode" -RecipientFilter "Office -eq '$SiteCode'"

  $mailboxes = [Object[]](Get-Mailbox -Filter "Office -eq '$SiteCode'")

  $i = 1

  Foreach($mbx in $mailboxes){
    Write-Progress -Activity "Updating address list" -PercentComplete (100*$i / $mailboxes.Count)
    $mbx | Set-Mailbox -SimpleDisplayName $mbx.SimpleDisplayName
    $i++
  }

}

main
