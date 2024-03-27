$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"

$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Specify the Space to search in
$spaceName = "Default"

# Specify the Variable Value to find, without OctoStache syntax 

$variableValueToFind = "mytestvalue"

# Optional: set a path to export to csv
$csvExportPath = ""

$variableTracking = @()
$octopusURL = $octopusURL.TrimEnd('/')

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

Write-Host "Looking for usages of variable value named '$variableValueToFind' in space: '$spaceName'"

# Get variables from variable sets
$variableSets = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/libraryvariablesets?contentType=Variables&skip=0&take=5000" -Headers $header

foreach ($variableSet in $variableSets.Items)
{
    Write-Host "Checking variable set '$($variableSet.Name)'"
    
    $variableSetVariables = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/variables/variableset-$($variableSet.Id)" -Headers $header

    $matchingNamedVariables = $variableSetVariables.Variables | Where-Object {$_.Value -like "*$variableValueToFind*"}
    if($null -ne $matchingNamedVariables){
        foreach($match in $matchingNamedVariables){
            $result = [PSCustomObject]@{
                Project = $null
                VariableSet = $variableSet.Name
                MatchType = "Value in Library Set"
                Context = $match.Value
                Property = $null
                AddtionalContext = $match.Name
            }
            $variableTracking += $result
        }
    }

}

# Get all projects
$projects = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header

# Loop through projects
foreach ($project in $projects)
{
    Write-Host "Checking project '$($project.Name)'"
    # Get project variables
    $projectVariableSet = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/variables/$($project.VariableSetId)" -Headers $header

    # Check to see if variable is named in project variables.
    $ProjectMatchingNamedVariables = $projectVariableSet.Variables | Where-Object {$_.Value -like "*$variableValueToFind*"}
    if($null -ne $ProjectMatchingNamedVariables) {
        foreach($match in $ProjectMatchingNamedVariables) {
            $result = [pscustomobject]@{
                Project = $project.Name
                VariableSet = $null
                MatchType = "Named Project Variable"
                Context = $match.Value
                Property = $null
                AdditionalContext = $match.Name
            }
            
            # Add to tracking list
            $variableTracking += $result
        }
    }
}
    

if($variableTracking.Count -gt 0) {
    Write-Host ""
    Write-Host "Found $($variableTracking.Count) results:"
    $variableTracking
    if (![string]::IsNullOrWhiteSpace($csvExportPath)) {
        Write-Host "Exporting results to CSV file: $csvExportPath"
        $variableTracking | Export-Csv -Path $csvExportPath -NoTypeInformation
    }
}
