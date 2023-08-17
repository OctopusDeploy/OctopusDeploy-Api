$octopusBaseURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$headers = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

try {
    # Get space id
    $spaces = Invoke-RestMethod -Method Get -Uri "$octopusBaseURL/api/spaces/all" -Headers $headers -ErrorVariable octoError

    $spaces | ForEach-Object {
        $spaceId = $_.Id
        $spaceName = $_.Name
        Write-Host "Searching Space named $spaceName with id $spaceId"

        # Create space specific url
        $octopusSpaceUrl = "$octopusBaseURL/api/$spaceId"

        # Get tentacles
        try {
            $targets = Invoke-RestMethod -Method Get -Uri "$octopusSpaceUrl/machines/all" -Headers $headers -ErrorVariable octoError
            $workers = Invoke-RestMethod -Method Get -Uri "$octopusSpaceUrl/workers/all" -Headers $headers -ErrorVariable octoError

            Write-Host "Targets and workers with sha1RSA certificates in Space $spaceName"
            ($targets + $workers)
            | Where-Object { $_.Endpoint -and $_.Endpoint.CertificateSignatureAlgorithm -and $_.Endpoint.CertificateSignatureAlgorithm -eq "sha1RSA" }
            | ForEach-Object {
                Write-Host "`t$($_.Name)"
            }
        }
        catch {
            Write-Host "Error searching Space $spaceName. This could be a permission issue."
            Write-Host "Error message is $($octoError.Message)"
        }
    }
}
catch {
    Write-Host "There was an error during the request: $($octoError.Message)"
    exit
}
