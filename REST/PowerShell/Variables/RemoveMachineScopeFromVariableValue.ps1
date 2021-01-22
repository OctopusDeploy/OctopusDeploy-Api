$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "" # example https://myoctopus.something.com
$octopusAPIKey = "" # example API-XXXXXXXXXXXXXXXXXXXXXXXXXXX
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$projectName = "Your project name"
$variableName = "Your variable name"
$variableValue = "The value with incorrect scoping" # this script assumes the value exists only once
$targetToRemove = "The name of the target to remove"

# Get space
$spaces = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header)
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get target
$targets = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines?partialName=$([uri]::EscapeDataString($targetToRemove))&skip=0&take=100" -Headers $header)
$target = $targets.Items | Where-Object { $_.Name -eq $targetToRemove }

# Get project
$projects = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects?partialName=$([uri]::EscapeDataString($projectName))&skip=0&take=100" -Headers $header)
$project = $projects.Items | Where-Object { $_.Name -eq $projectName }

# Get project variables
$projectVariables = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/variables/$($project.VariableSetId)" -Headers $header

# Check to see if varialbe is already present
$variableToUpdate = $projectVariables.Variables | Where-Object { $_.Name -eq $variableName -and $_.Value -eq $variableValue }

if ($variableToUpdate) {
    if ($variableToUpdate.Scope.Machine -and $variableToUpdate.Scope.Machine -contains $target.Id) {
        Write-Host "Removing scope $targetToRemove ($($target.Id)) from variable $variableName"
        $machines = $variableToUpdate.Scope.Machine | Where-Object { $_ -ne $target.Id }
        $variableToUpdate.Scope.Machine = $machines

        Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/variables/$($project.VariableSetId)" -Headers $header -Body ($projectVariables | ConvertTo-Json -Depth 10)
    }
    else {
        Write-Host "Could not find target '$($target.Name)' in the scope for variable '$variableName' value '$variableValue'"
    }

}
else {
    Write-Host "Could not find the variable '$variableName' in project '$projectName'"
}
