[CmdletBinding()]
Param()

Function Import-SmithsDynamicModules {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,
    [string[]]$ModuleList = @()
  )
  $modules = @{}
  $moduleFiles = Get-ChildItem -Path "$smithsroot/modules/$Path" -Filter "*.psm1"
  If($ModuleList.Count -gt 0){
    $moduleFiles = $moduleFiles | Where { ($_.Name -replace "\.psm1","") -in $ModuleList }
  }

  Foreach($module in $moduleFiles){

    If($module.Name -match "^(.*)\.psm1$"){
      $prefix = $matches.1
      Write-SmithsLog -Level DEBUG -Activity "Loading Modules" -Message "Importing module $prefix"
      Import-Module -Name $module.FullName -Prefix $prefix -Force
      $modulePriority = Invoke-SmithsDynamicModuleFunction -Module $prefix -Function "Get-Priority" -OverrideCheck
      $modules.$prefix = $modulePriority
    }
    Else {
      Write-SmithsLog -Level ERROR -Activity "Loading modules" -Message "Unable to import module $prefix"
    }
  }
  $script:moduleList = [string[]]($modules.GetEnumerator() | Sort Value | Select -ExpandProperty Name)
  $script:moduleList

}

Function Invoke-SmithsDynamicModuleFunction {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Module,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Function,
    [Hashtable]$ArgumentList=@{},
    [switch]$OverrideCheck
  )

  Begin {
  }

  Process {


    If($OverrideCheck -or $Module -in $script:ModuleList){
      $fn = $Function -Replace "-", "-$Module"
      If((Get-Command -Name $fn -Module $Module)){
        #Write-SmithsLog -Level DEBUG -Activity "Function call" -Message "$Function in module $Module started"
        & $fn @ArgumentList
        #Write-SmithsLog -Level DEBUG -Activity "Function call" -Message "$Function in module $Module finished"
      }
      Else {
        Write-SmithsLog -Level ERROR -Activity "Function call" -Message "No such function $Function in module $Module"
      }
    }
    Else {
      #Write-SmithsLog -Level ERROR -Activity "Function call" -Message "No such module $Module"
    }
  }

  End {
  }
}


Function Invoke-SmithsDynamicModuleFunctionForAll {

  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Function,
    [Hashtable]$ArgumentList=@{}
  )

  $script:moduleList | Invoke-SmithsDynamicModuleFunction @PSBoundParameters
}

