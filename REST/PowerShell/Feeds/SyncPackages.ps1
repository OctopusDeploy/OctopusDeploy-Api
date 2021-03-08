[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet("FileVersions", "LatestVersion", "AllVersions")]
    [string] $VersionSelection = "FileVersions",

    [Parameter()]
    [string] $Path,

    [Parameter(Mandatory)]
    [string] $SourceUrl,

    [Parameter(Mandatory)]
    [string] $SourceApiKey,

    [Parameter()]
    [string] $SourceSpace = "Default",

    [Parameter(Mandatory)]
    [string] $DestinationUrl,

    [Parameter(Mandatory)]
    [string] $DestinationApiKey,

    [Parameter()]
    [string] $DestinationSpace = "Default",

    [Parameter()]
    $CutoffDate = $null
)

function Push-Package([string] $fileName, $package) {
    Write-Information "Package $fileName does not exist in destination"
    Write-Verbose "Downloading $fileName..."
    $download = $sourceHttpClient.GetStreamAsync($sourceOctopusURL + $package.Links.Raw).GetAwaiter().GetResult()

    $contentDispositionHeaderValue = New-Object System.Net.Http.Headers.ContentDispositionHeaderValue "form-data"
    $contentDispositionHeaderValue.Name = "fileData"
    $contentDispositionHeaderValue.FileName = $fileName 

    $streamContent = New-Object System.Net.Http.StreamContent $download
    $streamContent.Headers.ContentDisposition = $contentDispositionHeaderValue
    $contentType = "multipart/form-data"
    $streamContent.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue $contentType

    $content = New-Object System.Net.Http.MultipartFormDataContent
    $content.Add($streamContent)

    # Upload package
    $upload = $destinationHttpClient.PostAsync("$destinationOctopusURL/api/$destinationSpaceId/packages/raw?replace=false", $content)
        while (-not $upload.AsyncWaitHandle.WaitOne(10000)) {
        Write-Verbose "Uploading $fileName..."
    }

    $streamContent.Dispose()
}

function Skip-Package([string] $filename, $package, $cutoffDate) {
    if ($null -eq $cutoffDate) { 
        return $false; 
    }

    if ($package.Published -lt $cutoffDate) {
        Write-Warning "$filename was published on $($package.Published), which is earlier than the specified cut-off date, and will be skipped"
        return $true;
    }

    return $false
}

function Get-Packages([string] $packageId, [int] $batch, [int] $skip) {
    $getPackagesToSyncUrl = "$sourceOctopusURL/api/$sourceSpaceId/packages?nugetPackageId=$($package.Id)&take=$batch&skip=$skip"
    Write-Host "Fetching packages from $getPackagesToSyncUrl"
    $packagesResponse = Invoke-RestMethod -Method Get -Uri "$getPackagesToSyncUrl" -Headers $sourceHeader
    return $packagesResponse;
}

function Get-PackageExists([string] $filename, $package) {
    Write-Host "Checking if $fileName exists in destination..."
    $checkForExistingPackageURL = "$destinationOctopusURL/api/$destinationSpaceId/packages/packages-$($package.Id).$($pkg.Version)" 
    $checkForExistingPackageResponse =  Invoke-WebRequest -Method Get -Uri $checkForExistingPackageURL -Headers $destinationHeader -SkipHttpErrorCheck 
    if ($checkForExistingPackageResponse.StatusCode -ne 404) {
        if ($checkForExistingPackageResponse.StatusCode -eq 200) {
            Write-Verbose "Package $fileName already exists on the destination. Skipping."
            return $true;
        } else {
            Write-Error "Unexpected status code $($checkForExistingPackageResponse.StatusCode) returned from $checkForExistingPackageURL"
        }
    } 
    return $false;
}

# This script syncs packages from the built-in feed between two spaces. 
# The spaces can be on the same Octopus instance, or in different instances

$ErrorActionPreference = "Stop"

# ******* Variables to be specified before running ********

# Source Octopus instance details and credentials
$sourceOctopusURL = $sourceUrl
$sourceOctopusAPIKey = $sourceApiKey
$sourceSpaceName = $sourceSpace

# Destination Octopus instance details and credentials
$destinationOctopusURL = $destinationUrl
$destinationOctopusAPIKey = $destinationApiKey
$destinationSpaceName = $destinationSpace

# *****************************************************

# Get spaces
$sourceHeader = @{ "X-Octopus-ApiKey" = $sourceOctopusAPIKey }
$sourceSpaceId = ((Invoke-RestMethod -Method Get -Uri "$sourceOctopusURL/api/spaces/all" -Headers $sourceHeader) | Where-Object {$_.Name -eq $sourceSpaceName}).Id

$destinationHeader = @{ "X-Octopus-ApiKey" = $destinationOctopusAPIKey }
$destinationSpaceId = ((Invoke-RestMethod -Method Get -Uri "$destinationOctopusURL/api/spaces/all" -Headers $destinationHeader) | Where-Object {$_.Name -eq $destinationSpaceName}).Id

# Create HTTP clients 
$sourceHttpClient = New-Object System.Net.Http.HttpClient
$sourceHttpClient.DefaultRequestHeaders.Add("X-Octopus-ApiKey", $sourceOctopusAPIKey)
$sourceHttpClient.Timeout = New-TimeSpan -Minutes 60

$destinationHttpClient = New-Object System.Net.Http.HttpClient
$destinationHttpClient.DefaultRequestHeaders.Add("X-Octopus-ApiKey", $destinationOctopusAPIKey)
$destinationHttpClient.Timeout = New-TimeSpan -Minutes 60

$totalSyncedPackageCount = 0
$totalSyncedPackageSize = 0

Write-Host "Syncing packages between $sourceOctopusURL and $destinationOctopusURL"

$packages = Get-Content -Path $path | ConvertFrom-Json

# Iterate supplied package IDs
foreach($package in $packages) {
    Write-Host "Syncing $($package.Id) packages (published after $cutoffDate)"
    $processedPackageCount = 0
    $skip=0;
    $batchSize = 100;
    
    if ($VersionSelection -eq 'AllVersions') {
        do {
            $packagesResponse = Get-Packages $package.Id $batchSize $skip
            foreach($pkg in $packagesResponse.Items) {
                Write-Host "Processing $($pkg.PackageId).$($pkg.Version)"
                $fileName = "$($pkg.PackageId).$($pkg.Version)$($pkg.FileExtension)"
                
                if (-not (Skip-Package $fileName $pkg $CutoffDate)) {
                    if (Get-PackageExists $fileName $package) {
                        $processedPackageCount++
                        continue;
                    } else {
                        Push-Package $fileName $pkg
                        $processedPackageCount++ 
                        $totalSyncedPackageCount++ 
                        $totalSyncedPackageSize += $pkg.PackageSizeBytes
                    }
                }
                else {
                    $processedPackageCount++
                }
            }

            $skip = $skip + $packagesResponse.Items.Count
        } while ($packagesResponse.Items.Count -eq $batchSize)
    }
    elseif ($VersionSelection -eq 'LatestVersion') {
        $packagesResponse = Get-Packages $package.Id 1 0
        $pkg = $packagesResponse.Items | Select-Object -First 1
        if ($null -ne $pkg) {
            $fileName = "$($pkg.PackageId).$($pkg.Version)$($pkg.FileExtension)"
            if (-not (Skip-Package $fileName $pkg $CutOffDate)) {
                if (Get-PackageExists $fileName $package) {
                    $processedPackageCount++
                    continue;
                } else {
                    Push-Package $fileName $pkg
                    $processedPackageCount++ 
                    $totalSyncedPackageCount++ 
                    $totalSyncedPackageSize += $pkg.PackageSizeBytes
                }
            }    
        }
    }
    elseif ($VersionSelection -eq "FileVersions") {
        $versions = $package.Versions;
        $packagesResponse = Get-Packages $package.Id $batchSize $skip
        
        do {
            foreach ($pkg in $packagesResponse.Items) {
                if ($versions.Contains($pkg.Version)) {
                    Write-Host "Processing $($pkg.PackageId).$($pkg.Version)"
                    $fileName = "$($pkg.PackageId).$($pkg.Version)$($pkg.FileExtension)"

                    if (-not (Skip-Package $fileName $pkg $CutoffDate)) {
                        if (Get-PackageExists $fileName $package) {
                            $processedPackageCount++
                            continue;
                        } else {
                            Push-Package $fileName $pkg
                            $processedPackageCount++ 
                            $totalSyncedPackageCount++ 
                            $totalSyncedPackageSize += $pkg.PackageSizeBytes
                        }
                    }
                    else {
                        $processedPackageCount++
                    }
                }
            }

            $skip = $skip + $packagesResponse.Items.Count
        } while ($packagesResponse.Items.Count -eq $batchSize)
    }

    Write-Host "$fileName sync complete. $processedPackageCount/$($packagesResponse.TotalResults)"
}

Write-Host "Sync complete.  $totalSyncedPackageCount packages ($("{0:n2}" -f ($totalSyncedPackageSize/1MB)) megabytes) were copied." -ForegroundColor Green