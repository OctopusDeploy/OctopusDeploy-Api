$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"

# Certificate details
$certificateName = "MyCertificate"
$certificateNotes = ""
$certificateFilePath = "path\to\pfxfile.pfx"
$certificatePfxPassword = "PFX-file-password"
$certificateEnvironmentIds = @()
$certificateTenantIds = @()
$certificateTenantTags = @()
$certificateTenantedDeploymentParticipation = "Untenanted"

# Convert PFX file to base64
$certificateContent = [Convert]::ToBase64String((Get-Content -Path $certificateFilePath -Encoding Byte))


# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Create JSON payload
$jsonPayload = @{
    Name = $certificateName
    Notes = $certificateNotes
    CertificateData = @{
        HasValue = $true
        NewValue = $certificateContent
    }
    Password = @{
        HasValue = $true
        NewValue = $certificatePfxPassword
    }
    EnvironmentIds = $certificateEnvironmentIds
    TenantIds = $certificateTenantIds
    TenantTags = $certificateTenantTags
    TenantedDeploymentParticipation = $certificateTenantedDeploymentParticipation
}

# Submit request
Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/certificates" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $header