[CmdletBinding()]
Param()

$script:activity = "User Photo"

Function Update-Mailboxes {

  [CmdletBinding()]
  Param(
    [switch]$ReadOnly
  )

  $script:photoDirectory = Get-SmithsConfigSetting -Component "Exchange Online" -Name "Photo Directory"
  #$script:photoDirectory = "Z:/"
  $script:processedDirectory = "$($script:photoDirectory)processed/done"
  $script:badDirectory = "$($script:photoDirectory)processed/bad"
  $script:skippedDirectory = "$($script:photoDirectory)processed/skipped"

  Write-SmithsLog -Level DEBUG -Activity $script:activity -Message "Starting"

  $photos = Get-ChildItem -Path $script:photoDirectory

  $processed = New-Object System.Collections.ArrayList

  $files = Get-ChildItem -Path $script:photoDirectory -File | Select-Object -Property FullName,Extension,Name,@{label="Username";expression={($_.BaseName -split " ")[0]}}, @{label="Datestamp";expression={[Datetime]::ParseExact(($_.BaseName -split " ")[1] , "yyyy-MM-ddTHH-mm-ss", $null)}} | Sort-Object -Property Datestamp -Descending

  Foreach($file in $files){
    If($file.Extension -match "jpe?g$"){
      # File is a JPEG
      If($file.Username -notin $processed){
        $x = $processed.Add($file.Username)
        Write-SmithsLog -Level DEBUG -Activity $script:activity -Identity $file.Username -Message "$($file.Name): processing photo"
        Try {
          $user = Get-ADUser -Identity $file.Username
          $mailbox = Get-Mailbox -Identity $user.UserPrincipalName
          If($mailbox -eq $null){
            Write-SmithsLog -Level ERROR -Activity $script:activity -Identity $file.Username -Message "Unable to find mailbox, skipping"
          }
          Else {
            Write-SmithsLog -Level DEBUG -Activity $script:activity -Identity $file.Username -Message "$($file.Name): uploading"
            If(-not $ReadOnly){
              Set-UserPhoto -Identity $user.UserPrincipalName -PictureData ([System.IO.File]::ReadAllBytes($file.FullName)) -Confirm:$false
              Move-Item -Path $file.FullName -Destination $script:processedDirectory
            }
          }
        }
        Catch {
        }
      }
      Else {
        Write-SmithsLog -Level DEBUG -Activity $script:activity -Identity $file.Username -Message "$($file.Name): more recent photo already processed, skipping"
        If(-not $ReadOnly){
          Move-Item -Path $file.FullName -Destination $script:skippedDirectory
        }
      }
    }
    Else {
      Write-SmithsLog -Level ERROR -Activity $script:activity -Message "$($file.Name): unsupported file format, moving to bad directory"
      If(-not $ReadOnly){
        Move-Item -Path $file.FullName -Destination $script:badDirectory
      }
    }
  }

}


Function Get-Priority {

  [CmdletBinding()]
  Param()

  40

}



