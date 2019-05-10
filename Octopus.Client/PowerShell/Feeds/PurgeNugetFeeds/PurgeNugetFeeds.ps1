<#

.SYNOPSIS
Applies Octopus release retention policies to associated packages on NuGet feeds.

.DESCRIPTION
Mimics how Octopus natively applies retention policies to its Built-in Package Repository, but applies them to
external NuGet feeds. ref: https://octopus.com/docs/administration/retention-policies#built-in-repository

Uses Octopus and NuGet APIs to identify and delete any package that meets all of these criteria:
* the package is on an Octopus-configured External Feed that:
 * is of type Nuget Feed
 * has a feed username (API key) defined
 * meets the -ExcludeFeedRegex and -IncludeFeedRegex criteria
* the package's name is associated with an Octopus release
* the package's name/version combination is not associated with an Octopus release
* the package's version is lower than the highest version of the package associated with an Octopus release

.PARAMETER ExcludeFeedRegex
Packages will not be purged from feeds having URLs that match this regular expression. Examples:
-ExcludeFeedRegex '$^' # Default. Purge packages from any feeds with URLs that match -IncludeFeedRegex.
-ExcludeFeedRegex '/foo-core/' # Do not purge packages from e.g. feed http://foonugetserver/foo-core/nuget

.PARAMETER IncludeFeedRegex
Packages will not be purged from feeds having URLs that do not match this regular expression. Examples:
-IncludeFeedRegex '.*' # Default. Purge packages from any feeds except those with URLs that match -ExcludeFeedRegex.
-IncludeFeedRegex 'foo-hi' # Purge packages from e.g. feed http://foonugetserver/foo-hi/nuget

.PARAMETER OctopusUri
Example:
-OctopusUri 'http://foooctoserver/api'

.PARAMETER OctopusApiKey
Duh.

.PARAMETER NugetPath
Full path to the nuget CLI executable.

.PARAMETER SpaceId
The space ID (not name). This only affects which NuGet feeds are queried for candidate packages to purge. Example:
-SpaceId 'Spaces-1' # Default

.PARAMETER UseCachedListOfPackagesInUse
Intended only to speed up debugging. Loads the list of packages associated with Octopus releases from a file
saved during the previous run instead of calculating the list by querying Octopus. Example:

.OUTPUTS

None

.EXAMPLE

Syntax for Arguments parameter of TFS Powershell step:
-Confirm:$($false) -WhatIf:$$(Foo.WhatIf) -Verbose:$$(system.debug) -IncludeFeedRegex '/foo-' -ExcludeFeedRegex '/foo-core/' -OctopusUri '$(Foo.OctopusUri)' -OctopusApiKey '$(Foo.OctopusApiKey)'

#>
[CmdletBinding(SupportsShouldProcess)] # Enable -WhatIf and -Verbose switches
Param(
	[parameter()][string]$ExcludeFeedRegex = '$^',
	[parameter()][string]$IncludeFeedRegex = '.*',
	[parameter(Mandatory=$true)][string]$OctopusUri,
	[parameter(Mandatory=$true)][string]$OctopusApiKey,
	[parameter(Mandatory=$true)][string]$NugetPath,
	[parameter()][string]$SpaceId = 'Spaces-1',
	[parameter()][switch] $UseCachedListOfPackagesInUse
)
$ErrorActionPreference = 'Stop'
if ($PSBoundParameters['Debug']) {
    $DebugPreference = 'Continue' # avoid Inquire
}
Write-Verbose 'Loading dependent assemblies'
Add-Type -Path '.\Newtonsoft.Json.dll'
Add-Type -Path '.\Octopus.Client.dll'
Add-Type -Path '.\Octostache.dll'

function Get-InUsePackages {
	[CmdletBinding()] # Enable -Verbose switch
	[OutputType('System.Collections.Generic.Dictionary[string,Octopus.Client.Model.PackageResource]')]
	Param ( 
		[parameter(Mandatory=$true)][Octopus.Client.Model.ReleaseResource]$Release
	)
	$packageVersions = @{}
	foreach ($selectedPackage in $Release.SelectedPackages) {
		$packageVersions[$selectedPackage.ActionName] = $selectedPackage.Version
	}
	$headers = @{ "X-Octopus-ApiKey" = $OctopusApiKey }
	$uri = [string]::Join('/', @(
		$OctopusUri.TrimEnd('/'), 
		$SpaceId,
		'deploymentprocesses', 
		$Release.ProjectDeploymentProcessSnapshotId))
	$progPref = $ProgressPreference
	$ProgressPreference = 'SilentlyContinue'
	$deploymentProcessSnapshot = Invoke-WebRequest -Uri $uri -Headers $headers -Method Get -Verbose:$false | ConvertFrom-Json
	$ProgressPreference = $progPref
	$selectedPackageVersions = New-Object 'System.Collections.Generic.Dictionary[string,Octopus.Client.Model.PackageResource]'
	foreach ($step in $deploymentProcessSnapshot.Steps) {
		foreach ($action in $step.Actions) {
			if ((!$action.IsDisabled) -and $packageVersions[$action.Name]) {
				foreach ($package in $action.Packages) {
					$selectedPackageVersion = New-Object 'Octopus.Client.Model.PackageResource'
					$selectedPackageVersion.FeedId = $package.FeedId
					$selectedPackageVersion.PackageId = Get-PackageId -Release $Release -PossibleOctostacheExpression $package.PackageId
					$selectedPackageVersion.Version = $packageVersions[$action.Name]
					$hash = $selectedPackageVersion.FeedId + ' ' + $selectedPackageVersion.PackageId + ' ' + $selectedPackageVersion.Version
					$selectedPackageVersions[$hash] = $selectedPackageVersion
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

Processing accounts for channels. Example:

    VERBOSE: Requesting deployment process snapshot for release 571 of 1403
    VERBOSE: '#{WebProjectPackageName}' evaluated to 'Foo.FooApp.Web'
    VERBOSE: '#{DataProjectPackage}' evaluated to 'Foo.FooApp.Dacpac'

    VERBOSE: Requesting deployment process snapshot for release 572 of 1403
    VERBOSE: '#{WebProjectPackageName}' evaluated to 'Foo.FooApp.MVC'
    VERBOSE: '#{DataProjectPackage}' evaluated to 'Foo.FooApp.DbSchema'
#>
function Get-PackageId {
	[CmdletBinding()] # Enable -Verbose switch
	[OutputType('System.String')]
	Param (
		[parameter(Mandatory=$true)][Octopus.Client.Model.ReleaseResource]$Release,
		[parameter(Mandatory=$true)][string]$PossibleOctostacheExpression
	)
	if ([Octostache.VariableDictionary]::CanEvaluationBeSkippedForExpression($PossibleOctostacheExpression)) {
		$PossibleOctostacheExpression
	} else {
		Write-Verbose "Attempting to evaluate possible Octostache expression '$PossibleOctostacheExpression'"
		$headers = @{ "X-Octopus-ApiKey" = $OctopusApiKey }
		$uri = [string]::Join('/', @(
			$OctopusUri.TrimEnd('/'), 
			$SpaceId,
			'variables', 
			$Release.ProjectVariableSetSnapshotId))
		$progPref = $ProgressPreference
		$ProgressPreference = 'SilentlyContinue'
		$variableSetSnapshots = @(Invoke-WebRequest -Uri $uri -Headers $headers -Method Get -Verbose:$false | ConvertFrom-Json)
		foreach ($libraryVariableSetSnapshotId in $Release.LibraryVariableSetSnapshotIds) {
			$uri = [string]::Join('/', @(
				$OctopusUri.TrimEnd('/'), 
				$SpaceId,
				'variables', 
				$libraryVariableSetSnapshotId))
				$variableSetSnapshots += Invoke-WebRequest -Uri $uri -Headers $headers -Method Get -Verbose:$false | ConvertFrom-Json
			}
		$ProgressPreference = $progPref
		$snapshottedVariables = New-Object 'Octostache.VariableDictionary'
		foreach ($variableSetSnapshot in $variableSetSnapshots) {
			foreach ($variable in $variableSetSnapshot.Variables) {
				if (
					((!$Release.ChannelId) -or (!$variable.Scope) -or (!$variable.Scope.Channel)) `
					-or `
					$variable.Scope.Channel.Contains($Release.ChannelId)
				) {
					$snapshottedVariables[$variable.Name] = $variable.Value
				}
			}			
		}
		$evaluated = $snapshottedVariables.Evaluate($PossibleOctostacheExpression)
		Write-Verbose "'$PossibleOctostacheExpression' evaluated to '$evaluated'"
		$evaluated
	}
}

function Remove-Package {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')] # Enable -WhatIf and -Verbose switches, require -Confirm:$false for non-interactive usage
    Param(
		[parameter(Mandatory=$true)][Octopus.Client.Model.NuGetFeedResource]$Feed,
		[parameter(Mandatory=$true)][string]$PackageName,
		[parameter(Mandatory=$true)][Octopus.Client.Model.SemanticVersion]$PackageVersion
	)
	if ($VerbosePreference -eq 'SilentlyContinue') { $nugetVerbosity = 'normal' } else { $nugetVerbosity = 'detailed' }
	$operation = "Deleting package '$PackageName.$($PackageVersion.ToNormalizedString())'"
	if ($PSCmdlet.ShouldProcess($Feed.FeedUri, $operation)) {
		Write-Host "$operation from feed '$($Feed.FeedUri)'"
		& $NugetPath delete $PackageName $PackageVersion.ToNormalizedString() -Source $Feed.FeedUri -Verbosity $nugetVerbosity -ApiKey $Feed.Username -NonInteractive
	}
}

function PurgeNugetFeeds() {
	[CmdletBinding()]
	Param()
	$octopusRepository = (new-object Octopus.Client.OctopusRepository (new-object Octopus.Client.OctopusServerEndpoint $OctopusURI, $OctopusApiKey))
	Write-Host 'Querying Octopus for releases'
	$releases = $octopusRepository.Releases.FindAll()
	$inUsePackagesDescription = 'list of packages associated with Octopus releases'
	$inUsePackagesCacheFile = "Cached $inUsePackagesDescription.xml"
    if ($UseCachedListOfPackagesInUse.IsPresent) {
		Write-Warning "Using cached $inUsePackagesDescription"
		$inUsePackages = Import-Clixml $inUsePackagesCacheFile
	} else {
		Write-Host "Compiling $inUsePackagesDescription"
		$inUsePackages = New-Object 'System.Collections.Generic.Dictionary[string,Octopus.Client.Model.PackageResource]'
		$releasesCount = $releases.Count
		$releasesProgress = 0
		foreach ($release in $releases) {
			$releasesProgress++
			Write-Progress -Activity "Compiling $inUsePackagesDescription" -PercentComplete (($releasesProgress / $releasesCount) * 100)
			Write-Verbose "Requesting deployment process snapshot for release $releasesProgress of $releasesCount"
			$releaseInUsePackages = Get-InUsePackages -Release $release
			foreach ($key in $releaseInUsePackages.Keys) {
				# no need to record this package if it was already recorded via another release
				if (!$inUsePackages[$key]) {
					$inUsePackages[$key] = $releaseInUsePackages[$key]
				}
			}
		}
		Write-Verbose "Saving $inUsePackagesDescription"
		$inUsePackages | Export-Clixml $inUsePackagesCacheFile -Force -WhatIf:$false -Confirm:$false
	}
	$inUsePackageNamesWithHighestVersion = New-Object 'System.Collections.Generic.Dictionary[string,Octopus.Client.Model.SemanticVersion]'
	foreach ($inUsePackage in $inUsePackages.Values) {
		if ((!$inUsePackageNamesWithHighestVersion[$inUsePackage.PackageId]) `
			-or ((New-Object 'Octopus.Client.Model.SemanticVersion' $inUsePackage.Version) `
				-gt $inUsePackageNamesWithHighestVersion[$inUsePackage.PackageId])
			) {
			$inUsePackageNamesWithHighestVersion[$inUsePackage.PackageId] = New-Object 'Octopus.Client.Model.SemanticVersion' $inUsePackage.Version
		}
	}
	Write-Host 'Querying Octopus for feeds'
	$inUseFeedIds = @($inUsePackages.Values | Select-Object -Property FeedId -Unique | % { $_.FeedId })
	$allFeeds = New-Object 'System.Collections.Generic.Dictionary[string,Octopus.Client.Model.NuGetFeedResource]'
	$octopusRepository.Feeds.FindAll() `
		| ? { $_.FeedType -eq [Octopus.Client.Model.FeedType]::NuGet } `
		| % { $allFeeds[$_.Id] = $_ }
	Write-Host 'Evaluating and processing feeds'
	foreach ($inUseFeedId in $inUseFeedIds) {
		if ($inUseFeedId -like 'feeds-builtin*') {
			Write-Verbose "Skipping feed '$inUseFeedId'. This script only handles external feeds."
		} elseif (!$allFeeds.ContainsKey($inUseFeedId)) {
			Write-Verbose "Skipping feed '$inUseFeedId'. Its details were not found even though it is associated with one or more packages from one or more releases."
		} elseif (
			($allFeeds[$inUseFeedId].FeedUri -match $ExcludeFeedRegex) -or `
			($allFeeds[$inUseFeedId].FeedUri -notmatch $IncludeFeedRegex)) {		
			Write-Verbose "Skipping feed '$inUseFeedId'. Its URL ($($allFeeds[$inUseFeedId].FeedUri)) does not comply with the ExcludeFeedRegex or IncludeFeedRegex parameters."
		} elseif ($allFeeds[$inUseFeedId].SpaceId -ne $SpaceId) {
			Write-Verbose "Skipping feed '$inUseFeedId' ($($allFeeds[$inUseFeedId].FeedUri)) from space '($allFeeds[$inUseFeedId].SpaceId)'. Only feeds in space '$SpaceId' are being processed, based on the SpaceId parameter (or its default value)."
		} elseif (!$allFeeds[$inUseFeedId].Username) {
			Write-Warning "Skipping feed '$inUseFeedId' ($($allFeeds[$inUseFeedId].FeedUri)). Its Username (API key) is not defined."
		} else {
			Write-Host "Processing feed '$inUseFeedId' ($($allFeeds[$inUseFeedId].FeedUri))."
			$listOutput = & $NugetPath list -Source $allFeeds[$inUseFeedId].FeedUri -AllVersions -Prerelease -NonInteractive
			if ($LastExitCode -ne 0 -or (!$listOutput)) {
				Write-Error "Unable to list packages on feed at $($allFeeds[$inUseFeedId].FeedUri)" -ErrorAction SilentlyContinue
			} else {
				foreach ($listLine in $listOutput) {
					# Parse and validate $listLine, which should be a package ID and version separated by a space
					$listLineParts = $listLine.Split(' ')
					if (!$listLineParts.Length -eq 2) {
						throw "The following line output from the nuget list command was not in the expected format: '$listLine'"
					}
					$listLineConcatenatedWithDot = [string]::Join('.', $listLineParts)
					$packageName = ''
					$packageVersion = $null
					if (![Octopus.Client.Util.PackageIdentityParser]::TryParsePackageIdAndVersion(
						$listLineConcatenatedWithDot, [ref]$packageName, [ref]$packageVersion)) {
						throw "The following line output from the nuget list command did not consist of a valid package ID and version: '$listLine'"
					}
					$preserveMessage = "Preserving package '$packageName.$($packageVersion.ToNormalizedString())' on $($allFeeds[$inUseFeedId].FeedUri)"
					if ($inUsePackageNamesWithHighestVersion.ContainsKey($packageName)) {
						$hash = $inUseFeedId + ' ' + $listLine
						if ($inUsePackages.ContainsKey($hash)) {
							Write-Verbose "$preserveMessage. It is associated with an Octopus release."
						} elseif ($packageVersion -gt $inUsePackageNamesWithHighestVersion[$packageName]) { # uses semantic comparison operator override
							Write-Verbose "$preserveMessage. Its version ($packageVersion) is higher than the highest version of '$packageName' associated with an Octopus release ($($inUsePackageNamesWithHighestVersion[$packageName])), so it may have been published for a future release."
						} else {
							Remove-Package -Feed $allFeeds[$inUseFeedId] -PackageName $packageName -PackageVersion $packageVersion
						}
					} else {
						Write-Verbose "$preserveMessage. No package named '$packageName' is associated with an Octopus release, so it may have been published for a future release."
					}
				}
			}
		}
	}
}

PurgeNugetFeeds
