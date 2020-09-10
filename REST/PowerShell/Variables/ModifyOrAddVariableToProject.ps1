# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$projectName = "MyProject"
$variable = @{
    Name = "MyVariable"
    Value = "MyValue"
    Type = "String"
    IsSensitive = $false
}

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get project
    $project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

    # Get project variables
    $projectVariables = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/variables/$($project.VariableSetId)" -Headers $header

    # Check to see if varialbe is already present
    $variableToUpdate = $projectVariables.Variables | Where-Object {$_.Name -eq $variable.Name}
    if ($null -eq $variableToUpdate)
    {
        # Create new object
        $variableToUpdate = New-Object -TypeName PSObject
        $variableToUpdate | Add-Member -MemberType NoteProperty -Name "Name" -Value $variable.Name
        $variableToUpdate | Add-Member -MemberType NoteProperty -Name "Value" -Value $variable.Value
        $variableToUpdate | Add-Member -MemberType NoteProperty -Name "Type" -Value $variable.Type
        $variableToUpdate | Add-Member -MemberType NoteProperty -Name "IsSensitive" -Value $variable.IsSensitive

        # Add to collection
        $projectVariables.Variables += $variableToUpdate

        $projectVariables.Variables
    }        

    # Update the value
    $variableToUpdate.Value = $variable.Value

    # Update the collection
    Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/variables/$($project.VariableSetId)" -Headers $header -Body ($projectVariables | ConvertTo-Json -Depth 10)
}
catch
{
    Write-Host $_.Exception.Message
}