$baseUri = "http://octopus.url" # <-- Update this to the base URL to your Octopus server(i.e. not including 'app' or 'api'
$apiKey = "API-xxxxxxxxxxxxxxxxxxxxxxxxxx" # <-- Update this to your API key
$headers = @{"X-Octopus-ApiKey" = $apiKey}
$libraryVariableSetId = "LibraryVariableSets-1" # <-- Update this to the Id of your variable set
$projectName = "ProejctName" # <-- Update this to the name of your project

function Get-OctopusResource([string]$uri) {
    Write-Host "[GET]: $uri"
    return Invoke-RestMethod -Method Get -Uri "$baseUri/$uri" -Headers $headers
}

function Put-OctopusResource([string]$uri, [object]$resource) {
    Write-Host "[PUT]: $uri"
    #Write-Output $resource | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Method Put -Uri "$baseUri/$uri" -Body $($resource | ConvertTo-Json -Depth 10) -Headers $headers
}

$libVarSet = Get-OctopusResource "api/libraryvariablesets/$libraryVariableSetId"
#Write-Output $libVarSet | ConvertTo-Json -Depth 10
$varSet = Get-OctopusResource "api/variables/$($libVarSet.VariableSetId)"
#Write-Output $varSet | ConvertTo-Json -Depth 10

$project = Get-OctopusResource "api/projects/$projectName"
#Write-Output $project | ConvertTo-Json -Depth 10
$projVar = Get-OctopusResource "api/variables/$($project.VariableSetId)"
#Write-Output $projVar | ConvertTo-Json -Depth 10

$varSet.Variables | % {
    if($_.IsSensitive) {
        $_.Value = ""
    }
    $projVar.Variables += $_
}

#Write-Host "Library Variable Set variables"
#Write-Output $varSet.Variables | Format-List
#Write-Host "Variables"
#Write-Output $projVar.Variables | Format-List

Put-OctopusResource "api/variables/$($projVar.Id)" $projVar