# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

Function Clear-SensitiveVariables
{
    # Define function variables
    param ($VariableCollection)

    # Loop through variables
    foreach ($variable in $VariableCollection)
    {
        # Check for sensitive
        if ($variable.IsSensitive)
        {
            $variable.Value = [string]::Empty
        }
    }

    # Return collection
    return $VariableCollection
}

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get all projects
    $projects = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header

    # Loop through projects
    foreach ($project in $projects)
    {
        # Get variable set
        $variableSet = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/variables/$($project.VariableSetId)" -Headers $header
        
        # Check for variables
        if ($variableSet.Variables.Count -gt 0)
        {
            $variableSet.Variables = Clear-SensitiveVariables -VariableCollection $variableSet.Variables

            # Update set
            Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/variables/$($project.VariableSetId)" -Body ($variableSet | ConvertTo-Json -Depth 10) -Headers $header
        }
    }

    # Get all libarary sets
    $variableSets = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/libraryvariablesets/all" -Headers $header

    # Loop through variablesets
    foreach ($variableSet in $variableSets)
    {
        # Get the variableset
        $variableSet = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/libraryvariablesets/$($variableSet.Id)" -Headers $header
        
        # Check for variables
        if ($variableSet.Variables.Count -gt 0)
        {
            $variableSet.Variables = Clear-SensitiveVariables -VariableCollection $variableSet.Variables

            # Update set
            Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/libraryvariablesets/$($variableSet.Id)" -Body ($variableSet | ConvertTo-Json -Depth 10) -Headers $header            
        }
    }
}
catch
{
    Write-Host $_.Exception.Message
}