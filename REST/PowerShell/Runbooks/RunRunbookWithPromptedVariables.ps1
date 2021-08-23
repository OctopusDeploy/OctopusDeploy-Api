$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = ""
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$spaceName = "Default"
$environmentName = ""
$runbookName = ""
$runbookSnapshotId = "" # Leave blank if you'd like to use the published snapshot
$variableName = @()     # Enter multiple comma separated values if you have multiple prompted variables (e.g. @("promptedvar","promptedvar2"))
$newValue = @()         # Enter multiple comma separated values if you have multiple prompted variables in the same order as the variable names above (e.g. @("value for promptedvar","value for promptedvar2"))

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }
$spaceId = $space.Id

# Get runbook
$runbooks = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/runbooks?partialName=$([uri]::EscapeDataString($runbookName))&skip=0&take=100" -Headers $header 
$runbook = $runbooks.Items | Where-Object { $_.Name -eq $runbookName }
$runbookId = $runbook.Id

# Get environment
$environments = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/environments?partialName=$([uri]::EscapeDataString($environmentName))&skip=0&take=100" -Headers $header 
$environment = $environments.Items | Where-Object { $_.Name -eq $environmentName }
$environmentId = $environment.Id

# Use published snapshot if no id provided
if ([string]::IsNullOrEmpty($runbookSnapshotId)) {
    $runbookSnapshotId = $runbook.PublishedRunbookSnapshotId
}

# Get runbook preview for environment
$runbookPreview = Invoke-RestMethod -Uri "$octopusURL/api/$($spaceId)/runbooks/$($runbookId)/runbookRuns/preview/$($EnvironmentId)?includeDisabledSteps=true" -Headers $header 

# Finds the element ID(s) you need to provide for the runbook
$elementItems = @() 
$formValues = @{ }
foreach ($name in $variablename){
    $element = $runbookPreview.Form.Elements | Where-Object { $_.Control.Name -eq $name }
    if($null -ne $element) {
        $elementItems += $element
    }
}

# Add the variables to the json.
For ($i=0; $i -lt $elementItems.Count; $i++) {
    $runbookPromptedVariableId = $elementItems[$i].Name
    $runbookPromptedVariableValue = $newvalue[$i]
    $formValues.Add($runbookPromptedVariableId, $runbookPromptedVariableValue)
}

# Create runbook Payload
$runbookBody = (@{
    RunBookId = $runbookId
    RunbookSnapshotId = $runbookSnapshotId
    EnvironmentId = $environmentId
    FormValues    = $formValues
    SkipActions = @()
    SpecificMachineIds = @()
    ExcludedMachineIds = @()
}) | ConvertTo-Json -Depth 10

# Run the runbook
Invoke-RestMethod -Method "POST" "$($octopusURL)/api/$($spaceid)/runbookRuns" -body $runbookBody -Headers $header -ContentType "application/json"
