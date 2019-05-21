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

.PARAMETER PathToStoreDataAcrossRuns
Full path to a folder where files from the script run can be accessed by the subsequent script run. Example:
-PathToStoreDataAcrossRuns '\\foonas\fooshare\Octopus-PurgeNugetFeeds-Data'

.PARAMETER SpaceId
The space ID (not name). This only affects which NuGet feeds are queried for candidate packages to purge. Example:
-SpaceId 'Spaces-1' # Default

.PARAMETER ProceedEvenIfPreviousRunMayHavePurgedPackagesItShouldNotHave
If this switch is present, the script will ignore the result of the following check: At the beginning of each
run, the script saves a file under -PathToStoreDataAcrossRuns listing any packages that Octopus reports as
missing from feeds that comply with -ExcludeFeedRegex and -IncludeFeedRegex. Just before saving that file, the
script compares the current list with the one saved the previous time the script was run. If the current list
includes any packages that the previous list does not, the cause could be that during the
previous run the script did not work as intended and purged packages still associated with releases.
To avoid the possibility of further data loss, the script throws an exception and stops without purging
anything (unless this switch is present).

.PARAMETER UseCachedListOfPackagesInUse
Intended only to speed up debugging. Loads the list of packages associated with Octopus releases from a file
saved during the previous run instead of calculating the list by querying Octopus. Example:

.OUTPUTS

None

.EXAMPLE

Syntax for Arguments parameter of TFS Powershell step:
-Confirm:$($false) -WhatIf:$$(foo.WhatIf) -Verbose:$$(system.debug) -IncludeFeedRegex '/foo-' -ExcludeFeedRegex '/foo-core/' -OctopusUri '$(foo.OctopusUri)' -OctopusApiKey '$(foo.OctopusApiKey)' -PathToStoreDataAcrossRuns $(foo.PathToStoreDataAcrossRuns)

#>
[CmdletBinding(SupportsShouldProcess)] # Enable -WhatIf and -Verbose switches
Param(
	[parameter()][string]$ExcludeFeedRegex = '$^',
	[parameter()][string]$IncludeFeedRegex = '.*',
	[parameter(Mandatory=$true)][string]$OctopusUri,
	[parameter(Mandatory=$true)][string]$OctopusApiKey,
	[parameter(Mandatory=$true)][string]$NugetPath,
	[parameter(Mandatory=$true)][string]$PathToStoreDataAcrossRuns,
	[parameter()][string]$SpaceId = 'Spaces-1',
    [parameter()][switch] $ProceedEvenIfPreviousRunMayHavePurgedPackagesItShouldNotHave,
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
$script:AllFeeds = New-Object 'System.Collections.Generic.Dictionary[string,Octopus.Client.Model.NuGetFeedResource]'
$script:ExcludedFeedIds = @()
$script:IncludedFeedIds = @()
if (!(Test-Path $PathToStoreDataAcrossRuns -PathType Container)) {
	New-Item -Path $PathToStoreDataAcrossRuns -ItemType 'directory' -Force  -WhatIf:$false -Confirm:$false
}

function Get-InUsePackages {
	[CmdletBinding()] # Enable -Verbose switch
	[OutputType('System.Collections.Generic.Dictionary[string, Octopus.Client.Model.PackageResource]')]
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
					$normalizedVersion = (New-Object 'Octopus.Client.Model.SemanticVersion' $packageVersions[$action.Name]).ToNormalizedString()
					$selectedPackageVersion.Version = $normalizedVersion
					$hash = [string]::Join(' ', @($selectedPackageVersion.FeedId, $selectedPackageVersion.PackageId, $selectedPackageVersion.Version))
					$selectedPackageVersions[$hash] = $selectedPackageVersion
				}
			}
		}
	}
	$selectedPackageVersions
}

function Test-FeedId {
    [CmdletBinding()]
	[OutputType('System.Boolean')]
    Param(
		[parameter(Mandatory=$true)][string]$FeedId
	)
	$result = $false
	if ($script:IncludedFeedIds.Contains($FeedId)) {
		$result = $true
	} elseif (!$script:ExcludedFeedIds.Contains($FeedId)) {
		if ($FeedId -like 'feeds-builtin*') {
			Write-Verbose "Skipping feed '$FeedId'. This script only handles external feeds."
		} elseif (!$script:AllFeeds.ContainsKey($FeedId)) {
			Write-Verbose "Skipping feed '$FeedId'. Its details were not found even though it is associated with one or more packages from one or more releases."
		} elseif (
			($script:AllFeeds[$FeedId].FeedUri -match $ExcludeFeedRegex) -or `
			($script:AllFeeds[$FeedId].FeedUri -notmatch $IncludeFeedRegex)) {		
			Write-Verbose "Skipping feed '$FeedId'. Its URL ($($script:AllFeeds[$FeedId].FeedUri)) does not comply with the ExcludeFeedRegex or IncludeFeedRegex parameters."
		} elseif ($script:AllFeeds[$FeedId].SpaceId -ne $SpaceId) {
			Write-Verbose "Skipping feed '$FeedId' ($($script:AllFeeds[$FeedId].FeedUri)) from space '($script:AllFeeds[$FeedId].SpaceId)'. Only feeds in space '$SpaceId' are being processed, based on the SpaceId parameter (or its default value)."
		} elseif (!$script:AllFeeds[$FeedId].Username) {
			Write-Warning "Skipping feed '$FeedId' ($($script:AllFeeds[$FeedId].FeedUri)). Its Username (API key) is not defined."
		} else {
			$result = $true
		}
		if ($result) {
			$script:IncludedFeedIds += $FeedId
		} else {
			$script:ExcludedFeedIds += $FeedId
		}
	}
	$result
}

function Test-PackagesWentMissingAfterPreviousRunStarted {
	[CmdletBinding()]
	[OutputType([void])]
    Param(
		[parameter(Mandatory=$true)][Octopus.Client.Model.PackageResource[]]$Packages,
		[parameter(Mandatory=$true)][Octopus.Client.Model.NugetFeedResource[]]$Feeds
	)		
	Write-Host 'Querying Octopus for any packages that may be missing from applicable feeds.'
	$packagesMissingNow = @{ 
		IncludedFeedIds = $null;
		PackagesMissing = Get-PackagesMissingFromFeeds -Packages $Packages -Feeds $Feeds
	}
	$packagesMissingNow.IncludedFeedIds = $script:IncludedFeedIds;
	Write-Verbose "$($packagesMissingNow.PackagesMissing.Count) packages are missing; $($packagesMissingNow.IncludedFeedIds.Count) applicable feeds were checked."
	$missingPackagesFile = [System.IO.Path]::Combine($PathToStoreDataAcrossRuns, "missing-packages-$($OctopusUri -replace '[^a-z0-9]', '-').xml")
	if (Test-Path $missingPackagesFile -PathType Leaf) {
		Write-Verbose "Loading list of packages Octopus reported missing from applicable feeds when the previous run started"
		$packagesMissingWhenPreviousRunStarted = Import-Clixml $missingPackagesFile
		Write-Verbose "$($packagesMissingWhenPreviousRunStarted.PackagesMissing.Count) packages were missing when the previous run started; $($packagesMissingWhenPreviousRunStarted.IncludedFeedIds.Count) applicable feeds were checked."
	} else {
		$packagesMissingWhenPreviousRunStarted = @{ IncludedFeedIds = @() ; PackagesMissing = New-Object 'System.Collections.Generic.List[Octopus.Client.Model.PackageResource]' }
		Write-Verbose "Found no preexisting file at $missingPackagesFile"
	}
	$regrets = @()
	foreach ($packageMissingNow in $packagesMissingNow.PackagesMissing) {
		if ($packagesMissingWhenPreviousRunStarted.IncludedFeedIds.Contains($packageMissingNow.FeedId) `
			-and @($packagesMissingWhenPreviousRunStarted.PackagesMissing | ? { 
				($_.FeedId -eq $packageMissingNow.FeedId) `
				-and ($_.PackageId -eq $packageMissingNow.PackageId) `
				-and ($_.Version -eq $packageMissingNow.Version)
			}).Count -eq 0) {			
			$regrets += $packageMissingNow
		}
	}
	if ($regrets.Count -gt 0) {
		$message = "The following package(s) that should have been retained went missing during or after the previous run of this script: $([string]::Join('; ', ($regrets | % { $_.FeedId + ' ' + $_.PackageId + ' ' + $_.Version })))"
		if ($ProceedEvenIfPreviousRunMayHavePurgedPackagesItShouldNotHave.IsPresent) {
			Write-Warning $message
		} else {
			throw $message
		}
	}
	# By design, this will not execute if the "throw" above executes.
	Write-Verbose "Saving list of packages missing from applicable feeds"
	$packagesMissingNow | Export-Clixml $missingPackagesFile -Force -WhatIf:$false -Confirm:$false
}

function Get-PackagesMissingFromFeeds {
    [CmdletBinding()]
	[OutputType('System.Collections.Generic.List[Octopus.Client.Model.PackageResource]')]
    Param(
		[parameter(Mandatory=$true)][Octopus.Client.Model.PackageResource[]]$Packages,
		[parameter(Mandatory=$true)][Octopus.Client.Model.NugetFeedResource[]]$Feeds
	)
	# If in the future you are considering requesting multiple packages at once as an optimization, note that
	# experimentation found that query strings a little longer than 14,000 characters could result in the
	# following response: "Bad Request - Request Too Long / HTTP Error 400. The size of the request headers is
	# too long."
	$packagesOnAffectedFeeds = $Packages | ? { Test-FeedId $_.FeedId }
	$packagesMissingFromFeeds = New-Object 'System.Collections.Generic.List[Octopus.Client.Model.PackageResource]'
	$headers = @{ 
		'X-Octopus-ApiKey' = $OctopusApiKey; 
		'Cache-Control' = 'no-cache';
		'Pragma' = 'no-cache'
	 }
	$packagesProgress = 0
	$progPref = $ProgressPreference
	$ProgressPreference = 'SilentlyContinue'
	foreach ($package in $packagesOnAffectedFeeds) {
		$packagesProgress++
		Write-Verbose "Requesting notes for package $packagesProgress of $($packagesOnAffectedFeeds.Count)"
		$uri = [string]::Join('/', @(
			$OctopusUri.TrimEnd('/'),
			$SpaceId,
			'packages',
			"notes?packageIds=$($package.FeedId)%3A$($package.PackageId)%3A$($package.Version)"))
		$packageNotes = Invoke-WebRequest -Uri $uri -Headers $headers -Method Get -Verbose:$false | ConvertFrom-Json
		if ($packageNotes.Packages[0].Notes.Succeeded -ne 'true') {
			$packagesMissingFromFeeds.Add($package)
		}
	}
	$ProgressPreference = $progPref
	$packagesMissingFromFeeds
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
    VERBOSE: '#{WebProjectPackageName}' evaluated to 'foo.BenefitsPlus.Web'
    VERBOSE: '#{DataProjectPackage}' evaluated to 'foo.BenefitsPlus.Dacpac'

    VERBOSE: Requesting deployment process snapshot for release 572 of 1403
    VERBOSE: '#{WebProjectPackageName}' evaluated to 'foo.BenefitsPlus.MVC'
    VERBOSE: '#{DataProjectPackage}' evaluated to 'foo.BenefitsPlus.DbSchema'
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

function Get-PackageIdAndVersion {
    [CmdletBinding()]
	[OutputType('System.Collections.Generic.HashSet[string]')]
    Param(
		[parameter(Mandatory=$true)][Octopus.Client.Model.NuGetFeedResource]$Feed
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
	
	$uri = [string]::Join('/', @(
		$Feed.FeedUri.TrimEnd('/'), 
		'Packages?$skip=0&$select=Id,NormalizedVersion&$orderby=Id,NormalizedVersion&$filter=Listed%20eq%20true'))
		# ref: https://www.odata.org/documentation/odata-version-2-0/uri-conventions/
	$packages = New-Object 'System.Collections.Generic.HashSet[string]'
	$resultPage = 1
	do {
		$progPref = $ProgressPreference
		$ProgressPreference = 'SilentlyContinue'
		$response = Invoke-WebRequest -Uri $uri -Method Get -Verbose:$false
		$ProgressPreference = $progPref
		Write-Progress -Activity "Parsing page $($resultPage++;$resultPage) of packages on $($Feed.FeedUri)"
		foreach ($packageProperties in ([xml]($response.Content)).feed.entry.properties) {
			$packages.Add([string]::Join('.', @($packageProperties.Id, $packageProperties.NormalizedVersion))) | Out-Null
		}
		$uri = ([xml]($response.Content)).feed.link | ? { $_.rel -eq 'next' } | % { $_.href }
	} while ($uri)
	$packages
}

function PurgeNugetFeeds() {
	[CmdletBinding()]
	Param()
	$octopusRepository = (new-object Octopus.Client.OctopusRepository (new-object Octopus.Client.OctopusServerEndpoint $OctopusURI, $OctopusApiKey))
	Write-Host 'Querying Octopus for releases'
	$releases = $octopusRepository.Releases.FindAll()
	$inUsePackagesDescription = 'list of packages associated with Octopus releases'
	$inUsePackagesCacheFile = [System.IO.Path]::Combine($PathToStoreDataAcrossRuns, "Cached $inUsePackagesDescription.xml")
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

	Write-Host 'Querying Octopus for feeds'
	$octopusRepository.Feeds.FindAll() `
		| ? { $_.FeedType -eq [Octopus.Client.Model.FeedType]::NuGet } `
		| % { $script:AllFeeds[$_.Id] = $_ }

	$inUsePackagesAsArray = New-Object 'Octopus.Client.Model.PackageResource[]' $inUsePackages.Values.Count
	$i=0; $inUsePackages.Values | % { $inUsePackagesAsArray[$i] = [Octopus.Client.Model.PackageResource]$_; $i++ }
	$allFeedsAsArray = New-Object 'Octopus.Client.Model.NugetFeedResource[]' $script:AllFeeds.Values.Count
	$i=0; $script:AllFeeds.Values | % { $allFeedsAsArray[$i] = [Octopus.Client.Model.NugetFeedResource]$_; $i++ }
	Test-PackagesWentMissingAfterPreviousRunStarted -Packages $inUsePackagesAsArray -Feeds $allFeedsAsArray

	$inUsePackageNamesWithHighestVersion = New-Object 'System.Collections.Generic.Dictionary[string,Octopus.Client.Model.SemanticVersion]'
	foreach ($inUsePackage in $inUsePackages.Values) {
		if ((!$inUsePackageNamesWithHighestVersion[$inUsePackage.PackageId]) `
			-or ((New-Object 'Octopus.Client.Model.SemanticVersion' $inUsePackage.Version) `
				-gt $inUsePackageNamesWithHighestVersion[$inUsePackage.PackageId])
			) {
			$inUsePackageNamesWithHighestVersion[$inUsePackage.PackageId] = New-Object 'Octopus.Client.Model.SemanticVersion' $inUsePackage.Version
		}
	}
	$inUseFeedIds = @($inUsePackages.Values | Select-Object -Property FeedId -Unique | % { $_.FeedId })
	Write-Host 'Evaluating and processing feeds'
	foreach ($inUseFeedId in $inUseFeedIds) {
		if (Test-FeedId -FeedId $inUseFeedId) {
			Write-Host "Processing feed '$inUseFeedId' ($($script:AllFeeds[$inUseFeedId].FeedUri))."
			$packagesOnFeed = Get-PackageIdAndVersion -Feed $script:AllFeeds[$inUseFeedId]
			foreach ($packageOnFeed in $packagesOnFeed) {
				# Parse and validate $packageOnFeed, which should be a package ID and version separated by a dot
				$packageName = ''
				$packageVersion = $null
				if (![Octopus.Client.Util.PackageIdentityParser]::TryParsePackageIdAndVersion(
					$packageOnFeed, [ref]$packageName, [ref]$packageVersion)) {
					throw "The output from Nuget packages API did not consist of a valid package ID and version: '$packageOnFeed'"
				}
				$preserveMessage = "Preserving package $packageOnFeed on $($script:AllFeeds[$inUseFeedId].FeedUri)"
				if ($inUsePackageNamesWithHighestVersion.ContainsKey($packageName)) {
					$hash = [string]::Join(' ', @($inUseFeedId, $packageName, $packageVersion.ToNormalizedString()))
					if ($inUsePackages.ContainsKey($hash)) {
						Write-Verbose "$preserveMessage. It is associated with an Octopus release."
					} elseif ($packageVersion -gt $inUsePackageNamesWithHighestVersion[$packageName]) { # uses semantic comparison operator override
						Write-Verbose "$preserveMessage. Its version ($($packageVersion.ToNormalizedString())) is higher than the highest version of '$packageName' associated with an Octopus release ($($inUsePackageNamesWithHighestVersion[$packageName])), so it may have been published for a future release."
					} else {
						Remove-Package -Feed $script:AllFeeds[$inUseFeedId] -PackageName $packageName -PackageVersion $packageVersion
					}
				} else {
					Write-Verbose "$preserveMessage. No package named '$packageName' is associated with an Octopus release, so it may have been published for a future release."
				}
			}
		}
	}
}

PurgeNugetFeeds
