<#

.SYNOPSIS
Updates the environment IDs in variable scopes.

Use case: After using Copy-LibraryVariables.ps1, the scopes of some variables in 
the target space include "Missing Resource" tags. By passing this script a list
of mappings between environment IDs in the source and target space the "missing 
resource" tags become the desired target-space environment tags after the fact.

You can find the environment IDs and names for each space using urls in the form
https://foo.com/api/Spaces-1/environments?skip=0&take=2147483647
where "Spaces-1" can be replaced by the ID of the space of interest.

.PARAMETER OctopusUri
Example:
-OctopusUri 'https://foo.com/api'

.PARAMETER OctopusApiKey
Note: Ensure that the account corresponding to the API key has the requisite 
permissions in the space designated by SpaceName.

.PARAMETER NugetPath
Full path to the nuget CLI executable. Example:
-NugetPath 'c:\foo\NuGet4.6.2.exe'

.PARAMETER SpaceName
The name (not ID) of the space in which the source variable set resides. Example:
-SpaceName 'Default' # Default, equivalent to space ID Spaces-1

.PARAMETER EnvironmentIDMappings
Example:
-EnvironmentIDMappings @{ 'Environments-1' = 'Environments-11'; 'Environments-99' = 'Environments-999'; }

.OUTPUTS
None

#>
[CmdletBinding(SupportsShouldProcess)] # Enable -WhatIf and -Verbose switches
Param(
	[parameter(Mandatory = $true)][string]$OctopusUri,
	[parameter(Mandatory = $true)][string]$OctopusApiKey,
	[parameter(Mandatory = $true)][string]$NugetPath,
	[parameter(Mandatory = $true)][string]$SpaceName,
	[parameter(Mandatory = $true)][Hashtable]$EnvironmentIDMappings
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

function UpdateEnvironments() {
	[CmdletBinding(SupportsShouldProcess)]
	Param(
		[parameter(Mandatory = $true)][string]$VariableSetId
	)
	Write-Host "Processing variable set '$VariableSetId'"
	$variableSets = $repository.VariableSets.Get($VariableSetId)
	if ($variableSets.Count -ne 1) {
		throw "Expected 1 variable set with id '$($VariableSetId)' but there were $($variableSets.Count)"
	}
	$variableSet = $variableSets[0]
	$changeMade = $false
	foreach ($variable in $variableSet.Variables.Where( { $_.Scope['Environment'] } )) {
		# A ScopeValue is a HashSet
		Write-Host "Processing variable '$($variable.Name)'"
		[Octopus.Client.Model.ScopeValue]$environmentScope = $variable.Scope['Environment']
		$originalEnvironmentScope = $environmentScope.Clone()
		foreach ($environmentId in $originalEnvironmentScope) {
			foreach ($key in $EnvironmentIDMappings.Keys.Where( { $originalEnvironmentScope.Contains($_) } )) {
				$environmentScope.Remove($key) | Out-Null
				$message = "'$key' will be removed; '$($EnvironmentIDMappings[$key])'"
				if ($environmentScope.Add($EnvironmentIDMappings[$key])) {
					Write-Host ($message + " will be added in its place" )
				} else {
					Write-Warning ($message + " was already present alongside it" )
				}
				$changeMade = $true
			}
		}
	}
	if ($changeMade) {
		$operation = 'Updating IDs of environments scoped to variables'
		if ($PSCmdlet.ShouldProcess($variableSet.Id, $operation)) {
			Write-Host "$operation in '$($variableSet.Id)'"
			$repository.VariableSets.Modify($variableSets)
		}
	}
}

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $OctopusUri, $OctopusApiKey 
$defaultSpaceRepository = New-Object Octopus.Client.OctopusRepository $endpoint
$repository = $defaultSpaceRepository.Client.ForSpace($defaultSpaceRepository.Spaces.FindByName($SpaceName))

$variableSetIds = @()
(
	$repository.LibraryVariableSets.GetAll() +
	$repository.Projects.GetAll()
) | % {
	$variableSetIds += $_.VariableSetId
}

$variableSetIds | % {
	UpdateEnvironments($_)
}
