# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"

# Certificate details
$certificateName = "MyCertificate"
$certificateFilePath = "path\to\pfx-file.pfx"
$certificatePfxPassword = "PFX-file-password"

# Convert PFX file to base64
$certificateContent = [Convert]::ToBase64String((Get-Content -Path $certificateFilePath -Encoding Byte))

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get existing certificate
    $certificate = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/certificates/all" -Headers $header) | Where-Object {($_.Name -eq $certificateName) -and ($null -eq $_.Archived)}

    # Check to see if multiple certificates were returned
    if ($certificate -is [array])
    {
        # Throw exception
        throw "Multiple certificates returned!"        
    }

    # Create JSON payload
    $jsonPayload = @{
        certificateData = $certificateContent
        password = $certificatePfxPassword
    }

    # Submit request
    Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/certificates/$($certificate.Id)/replace" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $header
}
catch
{
    Write-Host $_.Exception.Message
}