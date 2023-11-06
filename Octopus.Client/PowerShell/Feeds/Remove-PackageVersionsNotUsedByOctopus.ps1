<#

.SYNOPSIS
Important: Tested for deployment packages on ProGet (https://inedo.com/proget) NuGet feeds. When
using with other feed providers, set -DoDeletes $True to test-- it may turn out to be necessary to add a
variation of the Get-PackageOnFeed function.

Deletes from one or more feeds any package meeting all of these criteria:
 - ID in Octopus release(s)
 - version not in Octopus release(s)
 - published more than a specified timespan ago

Generates a .txt summary. Example:
  Feed 'https://foo.com/nuget/foo/v3/index.json' package counts:
   - 21251 total
   - 64 to retain because published after 11/16/2021 18:04:57 -05:00
   - 7803 to retain because no version of package ID referenced by any Octopus Release
   - 13384 will now be checked against package versions referenced by Octopus...
    - 266 to retain because referenced by Octopus Release(s)
    - 13118 to delete because published more than 720 hours ago and Releases reference other versions of the package's ID but not the package's own version
  Feed 'https://bar.com/nuget/bar/v3/index.json' package counts:
  [...]

Generates a .csv report with one row for every package version on the specified feed(s) and these columns:
 - Author
 - DetailsUri
 - DownloadUri
 - Id
 - NormalizedVersion
 - Published
 - FeedUri
 - HoursSincePublished
 - Delete (TRUE or FALSE)
 - Reason -- one of the following:
  - "delete because published more than [specified] hours ago and Releases reference other versions of the package's ID but not the package's own version"
  - "retain because no Release references any version of this package ID"
  - "retain because published within the past 720 hours"
  - "retain because referenced by Release(s)"
 - ReferencedByReleases ("NA" or newline-separated URLs)

 Generates a .csv deletions report with one row for every attempted package deletion
 - Author
 - DetailsUri
 - DownloadUri
 - Id
 - NormalizedVersion
 - Published
 - FeedUri
 - HoursSincePublished
 - DeleteSucceeded
 - TimeDeletedOrAttempted

.PARAMETER DoDeletes
Required. Boolean. Report files are generated regardless of value but packages are deleted only if True.
Value must be $True, $False, 0 (equivalent to $False) or a number greater than 0 (equivalent to $True)
Example:
-DoDeletes $True

.PARAMETER FeedApiKeys
Required. Hashtable of NuGet feed URLs and API keys, Example:
-FeedApiKeys @{'https://foo/feedA/v3/index.json' = 'foO0key'; 'https://foo/feedB/v3/index.json' = 'bArk3y'}

.PARAMETER OctopusApiKey
Required.

.PARAMETER OctopusUri
Required. Example:
-OctopusUri 'https://octopus.foo.com/api'

.PARAMETER PreserveRecentPackagesThresholdInHours
The script will ignore packages with Published timestamps less than this many hours before the start of the
script run. Decimals are allowed.
Default: 720 (30 days)
Example:
-PreserveRecentPackagesThresholdInHours ([int]([timespan]::FromDays(60).TotalHours))

.PARAMETER ReportFolder
The full path to a folder where files about the script run can be written before being added to Octopus as
artifacts

.PARAMETER NugetExePath
Local path where nuget.exe is present or to which this script will download it
Default: 'c:\temp\nuget-commandline\nuget.exe'

.PARAMETER NugetExeUrl
URL from which this script will download nuget.exe if not already present at NugetExePath
Default: 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe'

.PARAMETER FeedForOctopusAssemblies
Feed from which this script will download the Octopus Deploy packages Octopus.Client and Octostache, and their
dependencies.
Default: 'https://api.nuget.org/v3/index.json'

.PARAMETER NugetRequestTimeoutInSeconds
Number of seconds before queries for lists of packages from nuget feeds time out.
Default: 30

.NOTES
TODO: Add support for parallel deletes if running in PowerShell 7.1+

.OUTPUTS
None, but generates report files. See Synopsis for details.

.EXAMPLE
. .\Remove-PackageVersionsNotUsedByOctopus.ps1 `
  -DoDeletes $True `
  -FeedApiKeys @{'https://foo/feedA/v3/index.json' = 'foO0key'; 'https://foo/feedB/v3/index.json' = 'bArk3y'} `
  -OctopusApiKey 'FOO API KEY' `
  -OctopusUri 'https://octopus.foo.com/api' `
  -PreserveRecentPackagesThresholdInHours ([int]([timespan]::FromDays(30).TotalHours)) `
  -Verbose

#>
[CmdletBinding()] # Enable -Verbose switch
Param(
	[parameter(Mandatory = $true)][bool]$DoDeletes,
	[parameter(Mandatory = $true)][hashtable]$FeedApiKeys,
	[parameter(Mandatory = $true)][string]$OctopusApiKey,
	[parameter(Mandatory = $true)][string]$OctopusUri,
	[parameter(Mandatory = $false)][int]$PreserveRecentPackagesThresholdInHours = ([int]([timespan]::FromDays(30).TotalHours)),
	[parameter(Mandatory = $false)][string]$ReportFolder = (Join-Path $PWD 'Reports'),
	[parameter(Mandatory = $false)][string]$NugetExePath = 'c:\temp\nuget-commandline\nuget.exe',
	[parameter(Mandatory = $false)][string]$NugetExeUrl = 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe',
	[parameter(Mandatory = $false)][string]$FeedForOctopusAssemblies = 'https://api.nuget.org/v3/index.json',
	[parameter(Mandatory = $false)][int]$NugetRequestTimeoutInSeconds = 30
)
Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'
Write-Host "Executing script: $(Split-Path -Path $PSCommandPath -Leaf)"
Write-Host "Executing on $($env:COMPUTERNAME) as $(& whoami)"
if ($PSBoundParameters['Debug']) {
	$DebugPreference = 'Continue' # avoid Inquire
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "`$VerbosePreference`: $($VerbosePreference)"
Write-Host "`$OctopusUri`: $OctopusUri"
Write-Host "`$OctopusApiKey`: $([string]::new('*', $OctopusApiKey.Length))"
Write-Host "`$PreserveRecentPackagesThresholdInHours`: $PreserveRecentPackagesThresholdInHours"

foreach ($feedUri in $FeedApiKeys.Keys) {
	Write-Host "`$FeedApiKeys['$feedUri']`: $([string]::new('*', $FeedApiKeys[$feedUri].Length))"
	if (-not [uri]::IsWellFormedUriString($feedUri, [System.UriKind]::Absolute)) {
		throw [System.FormatException]::new("Feed URI is not in a valid format: $feedUri")
	}
	Write-Host "Testing Feed URI '$feedUri'"
	$statusCode = (Invoke-WebRequest $feedUri -UseBasicParsing -Verbose:$false).StatusCode
	if ($statusCode -ne 200) {
		throw "Status code was '$statusCode' rather than 200. Requested Feed URI '$feedUri' from computer '$env:COMPUTERNAME'."
	}
}

if (Test-Path Function:\Update-Progress) {
	function Write-Progress {
		[CmdletBinding()]
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'For Octopus Deploy context')]
		param(
			[string]$Activity,
			[string]$CurrentOperation,
			[int] $PercentComplete,
			[int] $SecondsRemaining
		)
  
		process {
			$message = $Activity
			if ($CurrentOperation) {
				$message += " / $CurrentOperation"
			}
			if ($SecondsRemaining) {
				$message += " - $([System.TimeSpan]::FromSeconds($SecondsRemaining).ToString('g')) remaining"
			}
			Update-Progress -Percentage $PercentComplete -Message $message
		}
	}
}

# Adapted from (ASD's own SO answer) https://stackoverflow.com/questions/5565029/check-if-full-path-given/35046453#35046453
function IsFullPath {
	[CmdletBinding()]
	[OutputType([bool])]
	Param(
		[parameter()][string]$Path
	)
	( `
	(-not [string]::IsNullOrWhiteSpace($Path)) `
		-and $Path.IndexOfAny([System.IO.Path]::GetInvalidPathChars()) -eq -1 `
		-and [System.IO.Path]::IsPathRooted($Path) `
		-and (-not [System.IO.Path]::GetPathRoot($Path).Equals([System.IO.Path]::DirectorySeparatorChar.ToString(), [StringComparison]::Ordinal)) `
		-and (-not [System.IO.Path]::GetPathRoot($Path).EndsWith([System.IO.Path]::VolumeSeparatorChar)) `
		)
}

if (-not (IsFullPath $ReportFolder)) {
	throw [System.ArgumentException]::new("ReportFolder must be a file system absolute path. Value: '$ReportFolder'", 'ReportFolder')
}
if (!(Test-Path $ReportFolder -PathType Container)) {
	New-Item -Path $ReportFolder -ItemType 'directory' -Force -WhatIf:$false -Confirm:$false | Out-Null
	Write-Host "Created ReportFolder $ReportFolder"
}

function Get-NugetExe {
	[CmdletBinding()]
	[OutputType([System.IO.FileInfo])]
	Param()
	if ((Test-Path $NugetExePath -PathType Leaf)) {
		Write-Host "'$NugetExePath' exists; no need to download"
	} else {
		Write-Host "'$NugetExePath' does not exist. Downloading from '$NugetExeUrl'"
		$nugetExeFolder = [System.IO.Path]::GetDirectoryName($NugetExePath)
		if (-not (Test-Path $nugetExeFolder -PathType Container)) {
			mkdir $nugetExeFolder | Out-Null
		}
		Invoke-WebRequest $NugetExeUrl -OutFile $NugetExePath -UseBasicParsing -Verbose:$false
	}
	[System.IO.FileInfo](Get-Item $NugetExePath)
}

function Get-OctopusAssemblies {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param(
		[parameter()][System.IO.DirectoryInfo]$NugetOutputDirectory,
		[parameter()][System.IO.FileInfo]$NugetExe
	)
	Write-Host "Acquiring packages containing Octopus assemblies from feed '$FeedForOctopusAssemblies'"
	Write-Host " - Will use '$($NugetExe.FullName)'"
	Write-Host " - Will extract to '$($NugetOutputDirectory.FullName)'"
	@('Octopus.Client', 'Octostache') | ForEach-Object { 
		. $NugetExe.FullName install $_ -Source $FeedForOctopusAssemblies -OutputDirectory $NugetOutputDirectory.FullName -ExcludeVersion -PackageSaveMode nuspec -Framework net40 -Verbosity $script:NugetVerbosity -NonInteractive | Out-Null
	}
}

function Load-OctopusAssemblies {
	[CmdletBinding()]
	[OutputType([System.Void])]
	Param(
		[parameter()][System.IO.DirectoryInfo]$NugetOutputDirectory,
		[parameter()][switch]$CheckExistingOnly
	)
	if ($CheckExistingOnly.IsPresent) {
		Write-Host 'Checking whether Octopus assemblies are already present'
	} else {
		Write-Host 'Consolidating Octopus assemblies'
	}
	$markdigLibParentPath = Join-Path $NugetOutputDirectory.FullName 'Markdig\lib'
	$destination = Join-Path $NugetOutputDirectory.FullName 'Octostache\lib\net40\'
	foreach ($path in $NugetOutputDirectory.FullName, $destination, $markdigLibParentPath) {
		if (-not (Test-Path $path -PathType Container)) {
			$message = "Folder '$path' not found"
			if ($CheckExistingOnly.IsPresent) {
				Write-Verbose $message
				return $false
			} else {
				throw [System.IO.DirectoryNotFoundException]::new($message)
			}
		}
	}
	$markdigLibPath = Get-ChildItem $markdigLibParentPath -Filter 'net4*' | Where-Object { $_.PSIsContainer } | Sort-Object Name -Descending | Select-Object -First 1 | ForEach-Object { $_.FullName }
	if (-not $markdigLibPath) {
		$message = "Did not find a folder matching '$(Join-Path $markdigLibParentPath 'net4*')'"
		if ($CheckExistingOnly.IsPresent) {
			Write-Verbose $message
			return $false
		} else {
			throw [System.IO.DirectoryNotFoundException]::new($message)
		}
	}
	$markdigPath = Join-Path $markdigLibPath 'Markdig.dll'
	$sprachePath = Join-Path $NugetOutputDirectory.FullName 'Sprache\lib\net40\Sprache.dll'
	foreach ($path in $markdigPath, $sprachePath) {
		$assemblyName = (Split-Path $path -Leaf)
		if ((Test-Path -LiteralPath (Join-Path $destination $assemblyName) -PathType Leaf)) {
			if (-not $CheckExistingOnly.IsPresent) {
				Write-Verbose "Octopus assembly '$assemblyName' is already present in '$destination'"
			}
		} else {
			if ($CheckExistingOnly.IsPresent) {
				return $false
			} else {
				Copy-Item $path $destination -WhatIf:$false
			}
		}
	}
	if ($CheckExistingOnly.IsPresent) {
		return $true
	}
	Write-Host 'Loading Octopus assemblies'
	@(
		'Newtonsoft.Json\lib\net40\Newtonsoft.Json.dll',
		'Octopus.Client\lib\net462\Octopus.Client.dll',
		'Octostache\lib\net40\Octostache.dll'
	) | ForEach-Object { 
		Add-Type -Path (Join-Path $NugetOutputDirectory.FullName $_)
	}
}

function Get-InUsePackages {
	[CmdletBinding()] # Enable -Verbose switch
	[OutputType('System.Collections.Generic.Dictionary[string, Octopus.Client.Model.PackageResource]')]
	Param ( 
		[parameter(Mandatory = $true)][Octopus.Client.Model.ReleaseResource]$Release
	)
	$packageVersions = @{ }
	foreach ($selectedPackage in $Release.SelectedPackages) {
		$packageVersions[$selectedPackage.ActionName] = $selectedPackage.Version
	}
	$headers = @{ "X-Octopus-ApiKey" = $OctopusApiKey }
	$uri = [string]::Join('/', @(
			$OctopusUri.TrimEnd('/'), 
			$Release.SpaceId,
			'deploymentprocesses', 
			$Release.ProjectDeploymentProcessSnapshotId)
	)
	if (-not (Test-Path variable:script:CachedResponses)) {
		$script:CachedResponses = @{}
	}
	if ($script:CachedResponses.ContainsKey($uri)) {
		$deploymentProcessSnapshot = $script:CachedResponses[$uri]
	} else {
		#Write-Verbose "Deployment process snaphot URI: $uri"
		$progPref = $ProgressPreference
		$ProgressPreference = 'SilentlyContinue'
		$deploymentProcessSnapshot = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -Verbose:$false
		$ProgressPreference = $progPref
		$script:CachedResponses.Add($uri, $deploymentProcessSnapshot)
	}

	$selectedPackageVersions = New-Object 'System.Collections.Generic.Dictionary[string,Octopus.Client.Model.PackageResource]'
	foreach ($step in $deploymentProcessSnapshot.Steps) {
		foreach ($action in $step.Actions) {
			if ((!$action.IsDisabled) -and $packageVersions[$action.Name] -and $action.ActionType -ne 'Octopus.DeployRelease') {
				foreach ($package in $action.Packages) {
					$packageDiagnosticText = "($($Release.SpaceId)/$($package.FeedId))/$(($OctopusUri -replace '/api$') + $Release.Links.Self)"
					$selectedPackageVersion = New-Object 'Octopus.Client.Model.PackageResource'
					$packageIDResult = Get-PackageId -Release $Release -PossibleOctostacheExpression $package.PackageId
					if (-not $packageIDResult.DefinitelyFullyResolved) {
						Write-Warning "'$($package.PackageId)' evaluated to '$($packageIDResult.Evaluated)'. $packageDiagnosticText"
						if (-not (Test-Path variable:script:CachedResponses)) {
							$script:CachedResponses = @{}
						}
					}
					$selectedPackageVersion.PackageId = $selectedPackageVersion.Id = `
						$selectedPackageVersion.Title = $packageIDResult.Evaluated
					try {
						$normalizedVersion = `
							[Octopus.Client.Model.SemanticVersion]::new($packageVersions[$action.Name]).ToNormalizedString()
					} catch {
						throw [System.FormatException]::new("Unable to normalize version number '$($packageVersions[$action.Name])' of '$($package.PackageId)' from $packageDiagnosticText. Exception was: $_", $_.Exception)
					}
					$selectedPackageVersion.Version = $normalizedVersion
					$packageHash = [string]::Join(' ', @($selectedPackageVersion.PackageId, $selectedPackageVersion.Version))
					$selectedPackageVersions[$packageHash] = $selectedPackageVersion
				}
			}
		}
	}
	$selectedPackageVersions
}

<#
	.SYNOPSIS
	Get-PackageId attempts to evaluate an Octostache expression from a release's deployment process snapshot using
	the same release's variable snapshots.
	
	Get-PackageId was implemented to address this scenario: Some process steps may define Octostache expressions 
	for the names of packages, for example to define different package names to use depending on a release's 
	channel. Unfortunately, deployment process snapshots contain only the octostache variable name, not the 
	evaluated package name (even though the dynamically-selected package version is recorded alongside it).
	
	Processing accounts for channels.
#>
function Get-PackageId {
	[CmdletBinding()] # Enable -Verbose switch
	Param (
		[parameter(Mandatory = $true)][Octopus.Client.Model.ReleaseResource]$Release,
		[parameter(Mandatory = $true)][string]$PossibleOctostacheExpression
	)
	if ([Octostache.VariableDictionary]::CanEvaluationBeSkippedForExpression($PossibleOctostacheExpression)) {
		[PSCustomObject]@{
			Evaluated               = $PossibleOctostacheExpression
			DefinitelyFullyResolved = $true
		}
	} else {
		#Write-Verbose "Attempting to evaluate possible Octostache expression '$PossibleOctostacheExpression'"
		$headers = @{ "X-Octopus-ApiKey" = $OctopusApiKey }
		if (-not (Test-Path variable:script:CachedResponses)) {
			$script:CachedResponses = @{}
		}
		$uri = [string]::Join('/', @(
				$OctopusUri.TrimEnd('/'), 
				$Release.SpaceId,
				'variables', 
				$Release.ProjectVariableSetSnapshotId))
		if ($script:CachedResponses.ContainsKey($uri)) {
			$variableSetSnapshots = $script:CachedResponses[$uri]
		} else {
			$progPref = $ProgressPreference
			$ProgressPreference = 'SilentlyContinue'
			$variableSetSnapshots = @(Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -Verbose:$false)
			$ProgressPreference = $progPref
			$script:CachedResponses.Add($uri, $variableSetSnapshots)
		}
		foreach ($libraryVariableSetSnapshotId in $Release.LibraryVariableSetSnapshotIds) {
			$uri = [string]::Join('/', @(
					$OctopusUri.TrimEnd('/'), 
					$Release.SpaceId,
					'variables', 
					$libraryVariableSetSnapshotId)
			)
			if ($script:CachedResponses.ContainsKey($uri)) {
				$variableSetSnapshots += $script:CachedResponses[$uri]
			} else {
				$progPref = $ProgressPreference
				$ProgressPreference = 'SilentlyContinue'
				$libraryVariableSetSnapshot = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -Verbose:$false
				$variableSetSnapshots += $libraryVariableSetSnapshot
				$ProgressPreference = $progPref
				$script:CachedResponses.Add($uri, $libraryVariableSetSnapshot)
			}
		}
		$snapshottedVariables = New-Object 'Octostache.VariableDictionary'
		foreach ($variableSetSnapshot in $variableSetSnapshots) {
			foreach ($variable in $variableSetSnapshot.Variables) {
				if (
					((-not $Release.ChannelId) -or (-not $variable.Scope) -or (-not $variable.Scope.psobject.Properties['Channel'])) `
						-or `
					($variable.Scope.psobject.Properties['Channel'] -and $variable.Scope.Channel.Contains($Release.ChannelId))
				) {
					$snapshottedVariables[$variable.Name] = $variable.Value
				}
			}
		}
		#Write-Verbose "'$PossibleOctostacheExpression' evaluated to '$evaluated'"
		$result = [PSCustomObject]@{
			Evaluated               = $snapshottedVariables.Evaluate($PossibleOctostacheExpression)
			DefinitelyFullyResolved = $false
		}
		if ([Octostache.VariableDictionary]::CanEvaluationBeSkippedForExpression($result.Evaluated)) {
			$result.DefinitelyFullyResolved = $true
		}
		$result
	}
}

function Get-PackageOnFeed {
	[CmdletBinding()]
	Param(
		[parameter(Mandatory = $true)][string]$FeedUri,
		[parameter(Mandatory = $true)][System.DateTimeOffset]$PublishedNoLaterThan,
		[parameter(Mandatory = $true)][System.Collections.Generic.HashSet[string]]$IncludeIds
	)
	# We consume the nuget API directly because of the following shortcomings of various API clients.
	# - NuGet CLI (list command from nuget.exe or NuGet.Commands.ListCommandRunner from
	#   nuget.client.dll): data corrpution possible due to wrapping of output if, for example,
	#   WindowsSize.Width or BufferSize.Width is less than the combined length of the package ID and version.
	#   refs:
	#   https://github.com/NuGet/NuGet.Client/blob/3803820961f4d61c06d07b179dab1d0439ec0d91/src/NuGet.Clients/NuGet.CommandLine/Common/Console.cs#L264
	#   https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.Commands/ListCommand/ListCommandRunner.cs#L154
	# - PackageManagement PowerShell module (Find-Package): not available on all environments; requires
	#   PowerShell 5.0
	# - Package Manager Console: Lacks a command to list packages without specifying a package ID

	$v2FeedUri = $FeedUri -replace '/v3/index.json$'
	$uri = [string]::Join('/', @(
			$v2FeedUri.TrimEnd('/'), 
			'Packages?$skip=0&$select=Id,NormalizedVersion,Published&$orderby=Id,NormalizedVersion&$filter=Listed%20eq%20true')
	) # ref: https://www.odata.org/documentation/odata-version-2-0/uri-conventions/
	$toBeChecked = [System.Collections.Generic.Dictionary[string, PSCustomObject]]::new()
	$retainedBecausePublishedRecently = [System.Collections.Generic.Dictionary[string, PSCustomObject]]::new()
	$retainedBecauseIDNotUsedByOctopus = [System.Collections.Generic.Dictionary[string, PSCustomObject]]::new()
	$resultPage = 1
	do {
		$progPref = $ProgressPreference
		$ProgressPreference = 'SilentlyContinue'
		$response = Invoke-WebRequest -Uri $uri -Method Get -TimeoutSec $NugetRequestTimeoutInSeconds -UseBasicParsing -Verbose:$false
		$ProgressPreference = $progPref
		Write-Progress -Activity "Parsing page $($resultPage++;$resultPage) of packages on $v2FeedUri"
		foreach ($packageEntry in ([xml]($response.Content)).feed.entry) {
			$author = $packageEntry.author.name
			$detailsUri = $packageEntry.id
			$downloadUri = $packageEntry.content.src
			$id = $packageEntry.title.InnerText
			$normalizedVersion = $packageEntry.properties.NormalizedVersion
			$published = [System.DateTimeOffset]::Parse($packageEntry.properties.Published.InnerText)
			$package = [PSCustomObject]@{
				Author              = $author
				DetailsUri          = $detailsUri
				DownloadUri         = $downloadUri
				ID                  = $id
				Published           = $published
				NormalizedVersion   = $normalizedVersion
				HoursSincePublished = [System.Math]::Round($inUsePackageInfo.QueryStartTime.Subtract($published).TotalHours, 1)
			}
			$packageHash = [string]::Join(' ', @($id, $normalizedVersion))
			if (-not $IncludeIds.Contains($id)) {
				$retainedBecauseIDNotUsedByOctopus[$packageHash] = $package
			} elseif ($published -gt $PublishedNoLaterThan) {
				$retainedBecausePublishedRecently[$packageHash] = $package
			} else {
				$toBeChecked[$packageHash] = $package
			}
		}
		$uri = ([xml]($response.Content)).feed.link | Where-Object { $_.rel -eq 'next' } | ForEach-Object { $_.href }
	} while ($uri)
	#Write-Progress -Activity "Parsing packages on $v2FeedUri" -Completed
	[PSCustomObject]@{
		RetainedBecauseIDNotUsedByOctopus = $retainedBecauseIDNotUsedByOctopus
		RetainedBecausePublishedRecently  = $retainedBecausePublishedRecently
		ToBeChecked                       = $toBeChecked
	}
}

<#

.SYNOPSIS
Throws if any required  system-level permissions are not present.
refs:
https://octopus.com/docs/security/users-and-teams/system-and-space-permissions
https://octopus.com/docs/security/users-and-teams/default-permissions#DefaultPermissions-SystemManager
https://octopus.com/docs/security/users-and-teams/default-permissions#DefaultPermissions-SpaceManager

#>
function Test-Permissions {
	[CmdletBinding()] # Enable -Verbose switch
	Param (
		[parameter(Mandatory = $true)][Octopus.Client.OctopusRepository]$OctopusRepository
	)

	$requiredSystemPermissions = @('SpaceView')
	$requiredSpacePermissions = @('ProjectView', 'ProcessView', 'VariableView',
		'VariableViewUnscoped', 'ReleaseView', 'LibraryVariableSetView',
		'ActionTemplateView', 'TenantView')

	$currentUser = $OctopusRepository.Users.GetCurrent()
	$uniqueIdentifyingClaims = $currentUser.Identities | ForEach-Object { $_.Claims.Keys | ForEach-Object { 
			$currentUser.Identities[0].Claims[$_] } | Where-Object { $_.IsIdentifyingClaim } } | 
		Select-Object Value -Unique | ForEach-Object { $_.Value }
	Write-Host "Connected to Octopus as: " +
	"$($currentUser | Select-Object Username, DisplayName, EmailAddress, Id); " +
	"Provider Claims=$($uniqueIdentifyingClaims -join ', ')"
	$userPermissionSet = $OctopusRepository.UserPermissions.Get($currentUser)
	foreach ($requiredPermission in $requiredSystemPermissions) {
		if (-not $userPermissionSet.SystemPermissions.Contains($requiredPermission)) {
			throw [System.Security.SecurityException]::new("Identity lacks the $requiredPermission system permission")
		}
	}
	$spaces = $octopusRepository.Spaces.GetAll()
	foreach ($requiredPermission in $requiredSpacePermissions) {
		$spacePermissions = $userPermissionSet.SpacePermissions[$requiredPermission]
		foreach ($space in $spaces) {
			$checkPassed = $false
			foreach ($spacePermission in $spacePermissions) {
				if ($spacePermission.SpaceId -eq $space.Id -and
					($spacePermission.RestrictedToProjectIds.Contains('projects-all') -or
					$spacePermission.RestrictedToProjectIds.Contains('projects-unrelated'))) {
					$checkPassed = $true
					break
				}
			}
			if (-not $checkPassed) {
				throw [System.Security.SecurityException]::new("Identity lacks the $requiredPermission permission in space $($space.Name)")
			}
		}
	}
}

function Remove-Package {
	[CmdletBinding()] # Enable -Verbose switch
	[OutputType([bool])]
	Param(
		[parameter(Mandatory = $true)][string]$FeedUri,
		[parameter(Mandatory = $true)][string]$ApiKey,
		[parameter(Mandatory = $true)][string]$PackageID,
		[parameter(Mandatory = $true)][string]$PackageVersion
	)
	$operation = "Deleting package '$PackageID $PackageVersion'"
	#Write-Host "$operation from feed $FeedUri"
	try {
		Write-Host "##octopus[stderr-progress]"
		. $nugetExe delete $PackageID $PackageVersion -Source $FeedUri -ApiKey $ApiKey -Verbosity detailed -NonInteractive | Out-Null
		$nugetExeSucceeded = $?
	} catch {
		$nugetExeSucceeded = $false
	} finally {
		Write-Host "##octopus[stderr-default]"
		if (-not $nugetExeSucceeded) {
			Write-Warning "nuget.exe failed during this operation: $operation"
			Write-Warning 'There may be verbose log output with additional details'
		}
	}
	$nugetExeSucceeded
}

function New-ReportRow {
	[CmdletBinding()] # Enable -Verbose switch
	Param (
		[parameter(Mandatory = $true)][string]$FeedUri,
		[parameter(Mandatory = $true)]$Package,
		[parameter(Mandatory = $true)][string]$Reason,
		[parameter(Mandatory = $true)][bool]$Delete,
		[parameter(Mandatory = $false)]$ReferencedByReleases
	)
	if ($ReferencedByReleases) {
		$ReleaseLinks = ($ReferencedByReleases | ForEach-Object { ($OctopusUri -replace '/api$') + $_.Links.Self } ) -join "`n"
	} else {
		$ReleaseLinks = 'NA'
	}
	[PSCustomObject]@{
		Author               = $Package.Author
		DetailsUri           = $Package.DetailsUri
		DownloadUri          = $Package.DownloadUri
		Id                   = $Package.Id
		NormalizedVersion    = $Package.NormalizedVersion
		Published            = $Package.Published
		FeedUri              = $FeedUri
		HoursSincePublished  = $Package.HoursSincePublished
		Delete               = $Delete
		Reason               = $Reason
		ReferencedByReleases = $ReleaseLinks
	}
}

function New-DeletionsReportRow {
	[CmdletBinding()] # Enable -Verbose switch
	Param (
		[parameter(Mandatory = $true)][string]$FeedUri,
		[parameter(Mandatory = $true)]$Package,
		[parameter(Mandatory = $true)][bool]$DeleteSucceeded,
		[parameter(Mandatory = $true)][System.DateTimeOffset]$TimeDeletedOrAttempted
	)
	[PSCustomObject]@{
		DeleteSucceeded        = $DeleteSucceeded
		TimeDeletedOrAttempted = $TimeDeletedOrAttempted
		Author                 = $Package.Author
		DetailsUri             = $Package.DetailsUri
		DownloadUri            = $Package.DownloadUri
		Id                     = $Package.Id
		NormalizedVersion      = $Package.NormalizedVersion
		Published              = $Package.Published
		FeedUri                = $FeedUri
		HoursSincePublished    = $Package.HoursSincePublished
	}
}

if ($VerbosePreference -eq 'SilentlyContinue') { 
	$script:NugetVerbosity = 'quiet' 
} else {
	$script:NugetVerbosity = 'normal' 
}
$reportFile = Join-Path $ReportFolder (
	[string]::Concat(@(
			[System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath),
			' report ',
		([datetime]::Now.ToString('u') -replace ':'),
			'.csv'
		)
	)
)
$summaryFile = [System.IO.Path]::ChangeExtension(
	($reportFile -replace ' report ', ' summary '),
	'.txt'
)
$deletionsReportFile = $reportFile -replace ' report ', ' deletions '
$summaryFile, $reportFile, $deletionsReportFile | ForEach-Object {
	if (Test-Path $_) {
		throw "File already exists: $_"
	}
}
$nugetExe = Get-NugetExe
if ((Load-OctopusAssemblies -CheckExistingOnly -NugetOutputDirectory $nugetExe.Directory) -eq $true) {
	Write-Verbose 'Octopus assembly packages are already downloaded and extracted'
} else {
	Get-OctopusAssemblies -NugetExe $nugetExe -NugetOutputDirectory $nugetExe.Directory
}
Load-OctopusAssemblies -NugetOutputDirectory $nugetExe.Directory
$octopusRepository = (New-Object Octopus.Client.OctopusRepository (New-Object Octopus.Client.OctopusServerEndpoint $OctopusURI, $OctopusApiKey))
Test-Permissions -OctopusRepository $octopusRepository
$inUsePackagesDescription = 'list of packages associated with Octopus releases'
$inUsePackageInfo = [PSCustomObject]@{
	Packages       = [System.Collections.Generic.Dictionary[string, PSCustomObject]]::new()
	PackageIds     = [System.Collections.Generic.HashSet[string]]::new()
	QueryStartTime = [System.DateTimeOffset]::Now
	QueryEndTime   = [System.DateTimeOffset]::MaxValue # placeholder
}
Write-Host 'Querying Octopus for Spaces'
$headers = @{ "X-Octopus-ApiKey" = $OctopusApiKey }
$uri = [string]::Join('/', @(
		$OctopusUri.TrimEnd('/'), 
		'spaces',
		'all'))
$progPref = $ProgressPreference
$ProgressPreference = 'SilentlyContinue'
$spaces = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -Verbose:$false
$ProgressPreference = $progPref
$releases = @()
$spaces | ForEach-Object {
	$space = [Octopus.Client.Model.SpaceResource]::new()
	$space.Id = $_.Id
	$space.Name = $_.Name
	$space.IsDefault = $_.IsDefault
	$space.Links = [Octopus.Client.Extensibility.LinkCollection]::new()
	$space.Links.Add('SpaceHome', [Octopus.Client.Extensibility.Href]::new($_.Links.SpaceHome)) | Out-Null
	Write-Host "Querying Octopus for releases in $($space.Id) ($($space.Name))"
	$releases += $octopusRepository.Client.ForSpace($space).Releases.FindAll()
}
Write-Host "Compiling $inUsePackagesDescription"
$releasesCount = $releases.Count
$releasesStartTime = [System.DateTimeOffset]::Now
$releasesProgress = 0
foreach ($release in $releases) {
	$proportionComplete = $releasesProgress / $releasesCount
	if ($releasesProgress -eq 0) {
		$secondsRemaining = -1
	} else {
		$secondsElapsed = [System.DateTimeOffset]::Now.Subtract($releasesStartTime).TotalSeconds
		$estimatedSeconds = $secondsElapsed / $proportionComplete
		$secondsRemaining = $estimatedSeconds - $secondsElapsed
	}
	Write-Progress -Activity "Compiling $inUsePackagesDescription" `
		-PercentComplete ($proportionComplete * 100) `
		-SecondsRemaining $secondsRemaining
	#Write-Verbose "Requesting deployment process snapshot for release $releasesProgress of $releasesCount with ID $($release.id)"
	$releaseInUsePackages = Get-InUsePackages -Release $release
	foreach ($key in $releaseInUsePackages.Keys) {
		if ($releaseInUsePackages[$key].PackageId -eq '') {
			throw "The deployment process snapshot for '$($release.id)' references a package with an ID that evaluates to empty string (''). The package's version is '$($releaseInUsePackages[$key].Version)'"
		}
		$inUsePackageInfo.PackageIds.Add($releaseInUsePackages[$key].PackageId) | Out-Null
		if (!$inUsePackageInfo.Packages[$key]) {
			$inUsePackageInfo.Packages[$key] = [PSCustomObject]@{
				Package  = $releaseInUsePackages[$key]
				Releases = @($release)
			}
		} else {
			$inUsePackageInfo.Packages[$key].Releases += $release
		}
	}
	$releasesProgress++
}
$inUsePackageInfo.QueryEndTime = [System.DateTimeOffset]::Now
#Write-Progress -Activity "Compiling $inUsePackagesDescription" -PercentComplete 100 -Completed
$publishedNoLaterThan = $inUsePackageInfo.QueryStartTime.Subtract( `
		[System.TimeSpan]::FromHours($PreserveRecentPackagesThresholdInHours))
$inUsePackageInfoQueryMinutes = [System.Math]::Round($inUsePackageInfo.QueryEndTime.Subtract( `
			$inUsePackageInfo.QueryStartTime).TotalMinutes, 1)
Write-Verbose "It took $inUsePackageInfoQueryMinutes minutes to compile $inUsePackagesDescription"

$summaryReportLines = @(
	"How we will determine which packages were published too recently to consider deleting:",
	" - PreserveRecentPackagesThresholdInHours is set to $PreserveRecentPackagesThresholdInHours.",
	" - The $inUsePackagesDescription was pulled from Octopus beginning $($inUsePackageInfo.QueryStartTime).",
	" - So packages published after $publishedNoLaterThan will not be considered for deletion."
)
$summaryReportLines | Write-Host
$summaryReportLines | Out-File $summaryFile -Append

$packagesToDelete = @{}
$feedUris = $FeedApiKeys.Keys
try {
	foreach ($feedUri in $feedUris) {
		$packagesOnFeed = Get-PackageOnFeed -FeedUri $feedUri -PublishedNoLaterThan $publishedNoLaterThan -IncludeIds $inUsePackageInfo.PackageIds
		$totalPackagesOnFeed = (
			$packagesOnFeed.ToBeChecked.Count + `
				$packagesOnFeed.RetainedBecausePublishedRecently.Count + `
				$packagesOnFeed.RetainedBecauseIDNotUsedByOctopus.Count
		)
		$summaryReportLines = @(
			'',
			"Feed '$feedUri' package counts:",
			" - $totalPackagesOnFeed total",
			" - $($packagesOnFeed.RetainedBecausePublishedRecently.Count) to retain because published after $PublishedNoLaterThan",
			" - $($packagesOnFeed.RetainedBecauseIDNotUsedByOctopus.Count) to retain because no version of package ID referenced by any Octopus Release",
			" - $($packagesOnFeed.ToBeChecked.Count) will now be checked against package versions referenced by Octopus..."
		)
		$summaryReportLines | Write-Host
		$summaryReportLines | Out-File $summaryFile -Append
		$packagesOnFeedReferencedByOctopus = [System.Collections.Generic.Dictionary[string, PSCustomObject]]::new()
		$packagesToDelete.Add($feedUri, [System.Collections.Generic.Dictionary[string, PSCustomObject]]::new())
		foreach ($packageId_VersionOnFeed in $packagesOnFeed.ToBeChecked.Keys) {
			if ($inUsePackageInfo.Packages.Keys.Contains($packageId_VersionOnFeed)) {
				$packagesOnFeedReferencedByOctopus.Add($packageId_VersionOnFeed, $packagesOnFeed.ToBeChecked[$packageId_VersionOnFeed])
			} else {
				$packagesToDelete[$feedUri].Add($packageId_VersionOnFeed, $packagesOnFeed.ToBeChecked[$packageId_VersionOnFeed])
			}
		}
		$deleteReason = "published more than $PreserveRecentPackagesThresholdInHours hours ago and Releases reference other versions of the package's ID but not the package's own version"
		$summaryReportLines = @(
			"  - $($packagesOnFeedReferencedByOctopus.Count) to retain because referenced by Octopus Release(s)",
			"  - $($packagesToDelete[$feedUri].Count) to delete because $deleteReason"
		)
		$summaryReportLines | Write-Host
		$summaryReportLines | Out-File $summaryFile -Append

		$reportRows = [System.Collections.Generic.List[PSCustomObject]]::new()
		foreach ($package in $packagesOnFeed.RetainedBecausePublishedRecently.Values) {
			$reason = "retain because published within the past $PreserveRecentPackagesThresholdInHours hours"
			$reportRows.Add((New-ReportRow -FeedUri $feedUri -Package $package -Reason $reason -Delete $false))
		}
		foreach ($package in $packagesOnFeed.RetainedBecauseIDNotUsedByOctopus.Values) {
			$reason = 'retain because no Release references any version of this package ID'
			$reportRows.Add((New-ReportRow -FeedUri $feedUri -Package $package -Reason $reason -Delete $false))
		}
		foreach ($package in $packagesOnFeedReferencedByOctopus.Values) {
			$reason = 'retain because referenced by Release(s)'
			$packageInfoFromOctopus = $inUsePackageInfo.Packages[([string]::Join(' ', @($package.ID, $package.NormalizedVersion)))]
			$reportRows.Add((New-ReportRow -FeedUri $feedUri -Package $package -Reason $reason -ReferencedByReleases $packageInfoFromOctopus.Releases -Delete $false))
		}	
		foreach ($package in $packagesToDelete[$feedUri].Values) {
			$reason = "delete because $deleteReason"
			$reportRows.Add((New-ReportRow -FeedUri $feedUri -Package $package -Reason $reason -Delete $true))
		}
		$reportRows | Export-Csv $reportFile -NoTypeInformation -Append -WhatIf:$false -Confirm:$false
	}
} finally {
	if (Test-Path Function:\New-OctopusArtifact) {
		New-OctopusArtifact	-FullPath $summaryFile -Name 'summary.txt'
		New-OctopusArtifact	-FullPath $reportFile -Name 'details.csv'
		Set-OctopusVariable -name 'Summary' -value ([string]::Join("`n", (Get-Content $summaryFile)))
	} else {
		Write-Host "PACKAGES REPORT: ""$reportFile"""
		Write-Host "PACKAGES SUMMARY: ""$summaryFile"""
	}
}

if ($DoDeletes) {
	$deletionsReportRows = [System.Collections.Generic.List[PSCustomObject]]::new()
	$packageCount = ($packagesToDelete.Values | Measure-Object -Sum -Property 'Count').Sum
	$activity = "Deleting $packageCount packages $deleteReason"
	$deletionsStartTime = [System.DateTimeOffset]::Now
	$deletionsProgress = 0
	try {
		foreach ($feedUri in $feedUris) {
			$currentOperation = "Deleting from '$feedUri'"
			foreach ($package in $packagesToDelete[$feedUri].Values) {
				$proportionComplete = $deletionsProgress / $packageCount
				if ($deletionsProgress -eq 0) {
					$secondsRemaining = -1
				} else {
					$secondsElapsed = [System.DateTimeOffset]::Now.Subtract($deletionsStartTime).TotalSeconds
					$estimatedSeconds = $secondsElapsed / $proportionComplete
					$secondsRemaining = $estimatedSeconds - $secondsElapsed
				}
				Write-Progress -Activity $activity -CurrentOperation $currentOperation `
					-PercentComplete ($proportionComplete * 100) `
					-SecondsRemaining $secondsRemaining
				$deleteSucceeded = Remove-Package -FeedUri $feedUri -ApiKey $FeedApiKeys[$feedUri] -PackageID $package.ID -PackageVersion ([Octopus.Client.Model.SemanticVersion]::new($package.NormalizedVersion))
				$deletionsReportRows.Add((New-DeletionsReportRow -FeedUri $feedUri -Package $package `
							-DeleteSucceeded $deleteSucceeded -TimeDeletedOrAttempted ([DateTimeOffset]::Now)
					))
				$deletionsProgress++				
			}
			$deletionsReportRows | Export-Csv $deletionsReportFile -NoTypeInformation -Append -WhatIf:$false -Confirm:$false
			$deletionsReportRows.Clear()
		}
	} finally {
		#Write-Progress -Activity $activity -PercentComplete ($proportionComplete * 100)
		Write-Host "Deletions finished in $([System.DateTimeOffset]::Now.Subtract($deletionsStartTime).ToString('g'))"
		if (Test-Path $deletionsReportFile -PathType Leaf) {
			if (Test-Path Function:\New-OctopusArtifact) {
				New-OctopusArtifact -FullPath $deletionsReportFile -Name 'deletions.csv'
			} else {
				Write-Host "DELETIONS REPORT: ""$deletionsReportFile"""
			}
		} else {
			Write-Warning "Deletions report not found (expected path: ""$deletionsReportFile"")"
		}
	}
}
Write-Host "Script finished in $([System.DateTimeOffset]::Now.Subtract($inUsePackageInfo.QueryStartTime).ToString('g'))"
