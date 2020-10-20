$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$tagsetName = "Upgrade Ring"
$tagsetDescription = "Describes which upgrade ring the tenant belongs to"

# Optional Tags to add in the format "Tag name", "Tag Color"
$optionalTags = @{}
$optionalTags.Add("Early Adopter", "#ECAD3F")
$optionalTags.Add("Stable", "#36A766")

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# See if tagset already exists
$tagsetResults = (Invoke-RestMethod -Method Get "$octopusURL/api/$($space.Id)/tagsets?partialName=$tagsetName" -Headers $header) 
if( $tagsetResults.TotalResults -gt 0) {
    throw "Existing tagset results found matching '$($tagsetName)'!"
}

$tags = @()
if($optionalTags.Count -gt 0)
{
    foreach ($tagName in $optionalTags.Keys) {
        $tag = @{
            Id = $null
            Name = $tagName
            Color = $optionalTags.Item($tagName)
            Description = ""
            CanonicalTagName = $null
        }
        $tags += $tag
    }
}
# Create tagset json payload
$jsonPayload = @{
    Name = $tagsetName
    Description = $tagsetDescription
    Tags = $tags
}

# Create tagset
Invoke-RestMethod -Method Post -Uri "$octopusURL/api/$($space.Id)/tagsets" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $header