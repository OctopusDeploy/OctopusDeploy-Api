<#

.SYNOPSIS
Copies a subset of variables from one library variable set to another

.PARAMETER OctopusUri
Example:
-OctopusUri 'https://foo.com/api'

.PARAMETER OctopusApiKey
Note: If copying between spaces, ensure that the account corresponding to the 
API key has the requisite permissions in both spaces.

.PARAMETER NugetPath
Full path to the nuget CLI executable. Example:
-NugetPath 'c:\foo\NuGet4.6.2.exe'

.PARAMETER SourceSpaceId
The ID (not name) of the space in which the source library variable set resides. Example:
-SpaceId 'Spaces-1' # Default

.PARAMETER SourceLibraryVariableSetId
Example:
-SourceLibraryVariableSetId 'LibraryVariableSets-1'

.PARAMETER DestinationSpaceId
The ID (not name) of the space in which the destination library variable set resides. Example:
-SpaceId 'Spaces-1' # Default

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
	[parameter()][string]$SourceSpaceId = 'Spaces-1',
	[parameter(Mandatory = $true)][string]$SourceLibraryVariableSetId,
	[parameter()][string]$DestinationSpaceId = 'Spaces-1',
	[parameter(Mandatory = $true)][string]$DestinationLibraryVariableSetId,
	[parameter(Mandatory = $true)][string]$VariableNameRegexPattern
)
$ErrorActionPreference = 'Stop'
if ($PSBoundParameters['Debug']) {
	$DebugPreference = 'Continue' # avoid Inquire
}

function AcquireAssemblies() {
	[CmdletBinding()]
	Param()
	Write-Host 'Acquiring dependent assemblies'
	@('Octopus.Client') | % { 
		& $NugetPath install $_ $nugetSourceArg $NugetSource -ExcludeVersion -PackageSaveMode nuspec -Framework net45 -Verbosity $script:NugetVerbosity -NonInteractive
	}
}

function LoadAssemblies() {
	[CmdletBinding()]
	Param()
	Write-Verbose 'Loading dependent assemblies'
	@(
		'.\Octopus.Client\lib\net452\Octopus.Client.dll'
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

function Get-OctopusResource([string]$uri, [string]$spaceId) {
	# Adapted from https://github.com/OctopusDeploy/OctopusDeploy-Api/blob/master/REST/PowerShell/Variables/MigrateVariableSetVariablesToProject.ps1
	$uriWithSpace = [string]::Join('/', @(
			$OctopusUri.TrimEnd('/'), 
			$spaceId))
	$fullUri = [string]::Join('/', @(
			$uriWithSpace,
			$uri))
	Write-Host "[GET]: $fullUri"
	return Invoke-RestMethod -Method Get -Uri $fullUri -Headers $headers
}

function Put-OctopusResource([string]$uri, [string]$spaceId, [object]$resource) {
	# Adapted from https://github.com/OctopusDeploy/OctopusDeploy-Api/blob/master/REST/PowerShell/Variables/MigrateVariableSetVariablesToProject.ps1
	$uriWithSpace = [string]::Join('/', @(
			$OctopusUri.TrimEnd('/'), 
			$spaceId))
	$fullUri = [string]::Join('/', @(
			$uriWithSpace,
			$uri))
	Write-Host "[PUT]: $fullUri"
	Invoke-RestMethod -Method Put -Uri $fullUri -Body $($resource | ConvertTo-Json -Depth 10) -Headers $headers
}

$sourceLibraryVariableSet = Get-OctopusResource "/libraryvariablesets/$SourceLibraryVariableSetId" $SourceSpaceId
$sourceGlobalVariableSetId = $sourceLibraryVariableSet.VariableSetId
$sourceGlobalVariableSet = Get-OctopusResource "/variables/$sourceGlobalVariableSetId" $SourceSpaceId
$destinationLibraryVariableSet = Get-OctopusResource "/libraryvariablesets/$DestinationLibraryVariableSetId" $DestinationSpaceId
$destinationGlobalVariableSetId = $destinationLibraryVariableSet.VariableSetId
$destinationGlobalVariableSet = Get-OctopusResource "/variables/$destinationGlobalVariableSetId" $DestinationSpaceId

$changeMade = $false
$sourceGlobalVariableSet.Variables | % {
	if ($_.Name -match $VariableNameRegexPattern) {
		if($_.IsSensitive) {
			Write-Warning "Variable '$($_.Name)' will not be copied. It is marked Sensitive, so its value cannot be read."
		} else {
			Write-Verbose "Preparing to add variable '$($_.Name)' with value '$($_.Value)' in '$destinationGlobalVariableSetId'"
			if (($SourceSpaceId -ne $DestinationSpaceId) -and $_.Scope -and ($_.Scope.Count -ne 0)) {
				$scopeCategories = @('Environment', 'Role')
				$scopeWarnings = @("You must ensure variable '$($_.Name)' with value '$($_.Value)' is scoped appropriately in the destination space.")
				$scopeWarningDetails = @()
				foreach ($scopeCategory in $scopeCategories) {
					if ($_.Scope.$scopeCategory) {
						$scopeWarningDetails += ("$scopeCategory(s): " +
							(@(foreach ($scopeId in $_.Scope.$scopeCategory) { $sourceGlobalVariableSet.ScopeValues.$("$scopeCategory`s").Where( { $_.Id -eq $scopeId }).Name }) -join ', '))
					}
				}
				$scopeWarnings += $("'$($_.Name)'/'$($_.Value)': " + $($scopeWarningDetails -join '; '))
				foreach ($scopeWarning in $scopeWarnings) { Write-Warning $scopeWarning }
			}
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
