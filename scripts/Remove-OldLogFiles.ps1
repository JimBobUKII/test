[CmdletBinding()]
Param([Switch]$ReadOnly)

$LogActivity = "Remove Log Files"
$LogComponent = "Maintenance"

Function Remove-LogFiles {

  [CmdletBinding()]
  Param()

  $cutoff = (Get-Date).AddDays(-30)
  [System.IO.FileInfo[]]$oldfiles = Get-ChildItem -Path "$smithsroot/logs" -Recurse -Filter "*.log" | Where { $_.LastWriteTime -lt $cutoff }
  If($oldfiles.Count -eq 0){
    Write-SmithsLog -Activity $LogActivity -Level DEBUG -Message "No old log files to remove"
  }
  Foreach($file in $oldfiles){
    Write-SmithsLog -Activity $LogActivity -Level DEBUG -Message "Removing $($file.Fullname)"
    If(-not $ReadOnly){
      $file | Remove-Item
    }
  }

}


Function main {

  Import-Module -Name (Resolve-Path -Path "$PSScriptRoot/../modules/Smiths.psm1") -Force
  Import-SmithsConfig -Overrides $Settings

  Import-SmithsModule -Name "SmithsLogging.psm1"
  Start-SmithsLog -Component "Remove Old Log Files" -LogRun:$false -ReadOnly:$false

  Remove-LogFiles

  Stop-SmithsLog -Component $LogComponent -Activity $LogActivity
}


main




