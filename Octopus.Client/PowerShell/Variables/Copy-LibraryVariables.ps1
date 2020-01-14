<#

.SYNOPSIS
Copies a subset of variables from one library variable set to another

.PARAMETER OctopusUri
Example:
-OctopusUri 'https://foo.com/api'

.PARAMETER OctopusApiKey
Duh.

.PARAMETER NugetPath
Full path to the nuget CLI executable. Example:
-NugetPath 'c:\foo\NuGet4.6.2.exe'

.PARAMETER SourceLibraryVariableSetId
Example:
-SourceLibraryVariableSetId 'LibraryVariableSets-1'

.PARAMETER DestinationLibraryVariableSetId
Example:
-DestinationLibraryVariableSetId 'LibraryVariableSets-2'

.PARAMETER VariableNameRegexPattern 
A Regular Expression that dictates which variables in the source variable set will be copied, based on
variable name. Case-insensitive.
Example 1, copy a single variable:
-VariableNameRegexPattern '^foo\.bar$'
Example 2, copy variables with names that begin with "foo.":
-VariableNameRegexPattern '^foo\..+'

.OUTPUTS
None

#>
[CmdletBinding(SupportsShouldProcess)] # Enable -WhatIf and -Verbose switches
Param(
	[parameter(Mandatory = $true)][string]$OctopusUri,
	[parameter(Mandatory = $true)][string]$OctopusApiKey,
	[parameter(Mandatory = $true)][string]$NugetPath,
	[parameter(Mandatory = $true)][string]$SourceLibraryVariableSetId,
	[parameter(Mandatory = $true)][string]$DestinationLibraryVariableSetId,
	[parameter(Mandatory = $true)][string]$VariableNameRegexPattern
)
$ErrorActionPreference = 'Stop'
if ($PSBoundParameters['Debug']) {
	$DebugPreference = 'Continue' # avoid Inquire
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function AcquireAssemblies() {
	[CmdletBinding()]
	Param()
	Write-Host 'Acquiring dependent assemblies'
	@('Octopus.Client') | % { 
		& $NugetPath install $_ $nugetSourceArg $NugetSource -ExcludeVersion -PackageSaveMode nuspec -Framework net40 -Verbosity $script:NugetVerbosity -NonInteractive
	}
}

function LoadAssemblies() {
	[CmdletBinding()]
	Param()
	Write-Verbose 'Loading dependent assemblies'
	@(
		# '.\Newtonsoft.Json\lib\net40\Newtonsoft.Json.dll', 
		'.\Octopus.Client\lib\net45\Octopus.Client.dll'
	) | % { Add-Type -Path $_ }
}


if ($VerbosePreference -eq 'SilentlyContinue') { 
	$script:NugetVerbosity = 'quiet' 
} else {
	$script:NugetVerbosity = 'normal' 
}
AcquireAssemblies
LoadAssemblies

$octopusRepository = (New-Object Octopus.Client.OctopusRepository (New-Object Octopus.Client.OctopusServerEndpoint $OctopusURI, $OctopusApiKey))

$headers = @{"X-Octopus-ApiKey" = $OctopusApiKey}

function Get-OctopusResource([string]$uri) {
  # From https://github.com/OctopusDeploy/OctopusDeploy-Api/blob/master/REST/PowerShell/Variables/MigrateVariableSetVariablesToProject.ps1
    Write-Host "[GET]: $uri"
    return Invoke-RestMethod -Method Get -Uri "$OctopusUri/$uri" -Headers $headers
}

function Put-OctopusResource([string]$uri, [object]$resource) {
  # Adapted from https://github.com/OctopusDeploy/OctopusDeploy-Api/blob/master/REST/PowerShell/Variables/MigrateVariableSetVariablesToProject.ps1
    Write-Host "[PUT]: $uri"
    Invoke-RestMethod -Method Put -Uri "$OctopusUri/$uri" -Body $($resource | ConvertTo-Json -Depth 10) -Headers $headers
}

$sourceLibraryVariableSet = Get-OctopusResource "/libraryvariablesets/$SourceLibraryVariableSetId"
$sourceGlobalVariableSetId = $sourceLibraryVariableSet.VariableSetId
$sourceGlobalVariableSet = Get-OctopusResource "/variables/$sourceGlobalVariableSetId"
$destinationLibraryVariableSet = Get-OctopusResource "/libraryvariablesets/$DestinationLibraryVariableSetId"
$destinationGlobalVariableSetId = $destinationLibraryVariableSet.VariableSetId
$destinationGlobalVariableSet = Get-OctopusResource "/variables/$destinationGlobalVariableSetId"

$changeMade = $false
$sourceGlobalVariableSet.Variables | % {
	if ($_.Name -match $VariableNameRegexPattern) {
		if($_.IsSensitive) {
			Write-Warning "Variable '$($_.Name)' will not be copied. It is marked Sensitive, so its value cannot be read."
		} else {
			Write-Host "Preparing to add variable '$($_.Name)' with value '$($_.Value)' in '$destinationGlobalVariableSetId'"
		    $destinationGlobalVariableSet.Variables += $_
			$changeMade = $true
		}
	}
}

if ($changeMade) {
	$operation = "Adding variables"
	if ($PSCmdlet.ShouldProcess($destinationGlobalVariableSetId, $operation)) {
		Write-Host "$operation to '$destinationGlobalVariableSetId'"
		Put-OctopusResource "/variables/$destinationGlobalVariableSetId" $destinationGlobalVariableSet
	}
} else {
	Write-Warning "No variables matching Regex '$VariableNameRegexPattern' were found in '$sourceGlobalVariableSetId'"
}
