$ErrorActionPreference = "Stop";

$OctopusApiKey = $OctopusParameters["Octopus.ApiKey"]
$OctopusServerUrl = $OctopusParameters["Octopus.Web.ServerUri"]
$header = @{ "X-Octopus-ApiKey" = $OctopusApiKey }
$spaceId = $OctopusParameters["Octopus.Space.Id"]

# Get all PackageIds from deployment
$packageIdKeys = $OctopusParameters.Keys | Where-Object { $_ -match "^Octopus\.Action.*\.PackageId$" }  | ForEach-Object { $_ } | Sort-Object -Property * -Unique
$packageBuildInfos = @()

foreach ($packageIdKey in $packageIdKeys) {
    $packageVersionKey = $packageIdKey -Replace ".PackageID", ".PackageVersion"
    $packageId = $OctopusParameters[$packageIdKey]
    $packageVersion = $OctopusParameters[$packageVersionKey]

    # It's possible to have multiple packages of the same version.
    $existingPackageBuildInfo = $packageBuildInfos | Where-Object { $_.PackageId -eq $packageId -and $_.PackageVersion -eq $packageVersion } | Select-Object -First 1
    if ($null -eq $existingPackageBuildInfo) {
        
        Write-Host "Getting build info for $packageId - ($packageVersion)"
        $buildInfoResults = (Invoke-RestMethod -Method Get -Uri "$OctopusServerUrl/api/$($spaceId)/build-information?packageId=$([uri]::EscapeDataString($packageId))&filter=$([uri]::EscapeDataString($packageVersion))" -Headers $header)
    
        if ($buildInfoResults.Items.Count -gt 0) {
            Write-Host "Build Info found for $packageId - ($packageVersion)"

            if ($buildInfoResults.Items.Count -gt 1) {
                Write-Warning "Multiple build information found for $packageId - ($packageVersion), taking first result."
            }

            $buildInformation = ($buildInfoResults.Items | Select-Object -First 1)

            $packageBuildInfos += @{
                PackageId        = $packageId
                PackageVersion   = $packageVersion
                BuildInformation = $buildInformation
            };
        }
    }
}

foreach ($package in $packageBuildInfos) {
    $buildInfoJson = $package.BuildInformation | ConvertTo-Json -Depth 10 -Compress
    Write-Host "Setting Build info variable for $($package.PackageId) - ($($package.PackageVersion))"
    Write-Verbose "BuildInformation is: $buildInfoJson"
    Set-OctopusVariable -name "BuildInformation_$($package.PackageId)_$($package.PackageVersion)" -value "$buildInfoJson"
}

Write-Highlight "Found $($packageBuildInfos.Count) build information records."
