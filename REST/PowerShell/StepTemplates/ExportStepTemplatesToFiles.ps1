# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"

try {
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object { $_.Name -eq $spaceName }

    # Get step templates
    $templates = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/actiontemplates?take=250" -Headers $header)

    mkdir "$PSScriptRoot/step-templates"

    $templates.Items | ForEach-Object {
        $template = $_
        $name = $template.Name.Replace(" ", "-")
        Write-Host "Writing $PSScriptRoot/step-templates/$name.json"
        ($template | ConvertTo-Json) | Out-File -FilePath "$PSScriptRoot/step-templates/$name.json"
    }
}
catch {
    Write-Host $_.Exception.Message
}