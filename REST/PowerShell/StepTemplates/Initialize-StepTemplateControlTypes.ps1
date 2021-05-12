$ErrorActionPreference = 'Stop';

# Define working variables
$octopusURL = "https://your.octopus.server"
$octopusAPIKey = "API-KEY"

function Invoke-PagedOctoGet($uriFragment)
{
    $items = @()
    $response = $null
    do {
        $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/$uriFragment" }
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ "X-Octopus-ApiKey" = $octopusAPIKey }
        $items += $response.Items
    } while ($response.Links.'Page.Next')

    $items
}

$stepTemplates = Invoke-PagedOctoGet "api/actiontemplates" | Where-Object { $_.CommunityActionTemplateId -eq $null }
foreach ($stepTemplate in $stepTemplates) {
    foreach ($parameter in $stepTemplate.Parameters) {
        if (!($parameter.DisplaySettings.PSObject.Properties.Name -match "Octopus.ControlType")) {
            $parameter.DisplaySettings = @{'Octopus.ControlType' = 'SingleLineText'}

            Invoke-RestMethod `
                -Method Put `
                -Uri "$octopusURL/api/actiontemplates/$($stepTemplate.Id)" `
                -Headers @{ "X-Octopus-ApiKey" = $octopusAPIKey } `
                -Body ($stepTemplate | ConvertTo-Json -Depth 5)
        }
    }
}
