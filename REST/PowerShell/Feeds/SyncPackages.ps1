# This script syncs packages from the built-in feed between two spaces. 
# The spaces can be on the same Octopus instance, or in different instances

$ErrorActionPreference = "Stop"

# ******* Variables to be specified before running ********

# Source Octopus instance details and credentials
$sourceOctopusURL = "https://octopus.acme.com"
$sourceOctopusAPIKey = "API-XXXXXXXXXXXXXXX"
$sourceSpaceName = "Default"

# Destination Octopus instance details and credentials
$destinationOctopusURL = "https://acme.octopus.app"
$destinationOctopusAPIKey = "API-XXXXXXXXXXXXXXXX"
$destinationSpaceName = "Acme Online"

# Replace with the packages you wish to sync
$packageIds = @(
    #"Acme.Web"
    #,"Acme.Database"
) 

# Don't sync packages older than this date 
$cutoffDate = Get-Date "02/02/2020"

# *****************************************************

# Get spaces
$sourceHeader = @{ "X-Octopus-ApiKey" = $sourceOctopusAPIKey }
$sourceSpaceId = ((Invoke-RestMethod -Method Get -Uri "$sourceOctopusURL/api/spaces/all" -Headers $sourceHeader) | Where-Object {$_.Name -eq $sourceSpaceName}).Id

$destinationHeader = @{ "X-Octopus-ApiKey" = $destinationOctopusAPIKey }
$destinationSpaceId = ((Invoke-RestMethod -Method Get -Uri "$destinationOctopusURL/api/spaces/all" -Headers $destinationHeader) | Where-Object {$_.Name -eq $destinationSpaceName}).Id

# Create HTTP clients 
$sourceHttpClient = New-Object System.Net.Http.HttpClient
$sourceHttpClient.DefaultRequestHeaders.Add("X-Octopus-ApiKey", $sourceOctopusAPIKey)

$destinationHttpClient = New-Object System.Net.Http.HttpClient
$destinationHttpClient.DefaultRequestHeaders.Add("X-Octopus-ApiKey", $destinationOctopusAPIKey)

$totalSyncedPackageCount = 0
$totalSyncedPackageSize = 0

Write-Host "Syncing packages between $sourceOctopusURL and $destinationOctopusURL"

# Iterate supplied package IDs
foreach($packageId in $packageIds) {
    Write-Host "Syncing $packageId packages (published after $cutoffDate)"
    $skip=0;
    $batchSize=100;
    $processedPackageCount = 0

    do {
        $getPackagesToSyncUrl = "$sourceOctopusURL/api/$sourceSpaceId/packages?nugetPackageId=$packageId&take=$batchSize&skip=$skip"
        Write-Verbose "Fetching packages from $getPackagesToSyncUrl"
        $packagesResponse = Invoke-RestMethod -Method Get -Uri "$getPackagesToSyncUrl" -Headers $sourceHeader    

        foreach($package in $packagesResponse.Items) {
            Write-Verbose "Processing $($package.PackageId).$($package.Version)"
            $fileName = "$($package.PackageId).$($package.Version)$($package.FileExtension)" 

            if ($package.Published -lt $cutoffDate) {
                Write-Verbose "$fileName was published on $($package.Published), which is earlier than the specified cut-off date, and will be skipped"
                $processedPackageCount++
                continue
            }

           # Write-Verbose "Checking if $fileName exists in destination..."
            $checkForExistingPackageURL = "$destinationOctopusURL/api/$destinationSpaceId/packages/packages-$packageId.$($package.Version)" 
            $checkForExistingPackageResponse =  Invoke-WebRequest -Method Get -Uri $checkForExistingPackageURL -Headers $destinationHeader -SkipHttpErrorCheck 

            if ($checkForExistingPackageResponse.StatusCode -ne 404) {
                if ($checkForExistingPackageResponse.StatusCode -eq 200) {
                    Write-Verbose "Package $fileName already exists on the destination. Skipping."
                    $processedPackageCount++
                    continue
                } else {
                    Write-Error "Unexpected status code $($checkForExistingPackageResponse.StatusCode) returned from $checkForExistingPackageURL"
                }
            } else {
                Write-Verbose "Package does not exist in destination"
            }

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
            
            $processedPackageCount++ 
            $totalSyncedPackageCount++ 
            $totalSyncedPackageSize += $package.PackageSizeBytes

            Write-Host "$fileName sync complete. $processedPackageCount/$($packagesResponse.TotalResults)"
        }

        $skip = $skip + $packagesResponse.Items.Count
    } while ($packagesResponse.Items.Count -eq $batchSize) 
}

Write-Host "Sync complete.  $totalSyncedPackageCount packages ($($totalSyncedPackageSize/1MB) megabytes) were copied." -ForegroundColor Green