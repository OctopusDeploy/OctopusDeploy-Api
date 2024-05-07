# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-####"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"
$projectName = "YOUR_PROJECT_NAME"
$stepNameToMove = "YOUR_STEP_NAME"
$newIndexForStep = 1 #Index is n-1 from the step number in the UI
 
# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object { $_.Name -eq $spaceName }
 
# Get project
$project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object { $_.Name -eq $projectName }

# Get deployment process
$deploymentProcess = (Invoke-RestMethod -Method Get -Uri "$octopusURL/$($project.Links.DeploymentProcess)" -Headers $header)

# Vars to loop through steps and find existing index
$stepCounter = 0
$oldIndexForStep = $newIndexForStep

# Find the index of the existing step
foreach ($step in $deploymentProcess.Steps){
    if($step.Name -eq $stepNameToMove){
        Write-Host "Found $($step.Name) to move at index $stepCounter"
        $oldIndexForStep = $stepCounter
    }
    $stepCounter++
}

$newSteps = @() # Record new order of steps
$oldStepCounter = 0 # Keep track of where we are in the original steps

# Loop through and add the steps in the new order
if ($oldIndexForStep -ne $newIndexForStep){
    for ($i=0; $i -lt $deploymentProcess.Steps.Length; $i++){
        if($i -eq $newIndexForStep){
            Write-Host "--Hit new index for step at $newIndexForStep, inserting $($deploymentProcess.Steps[$oldIndexForStep].Name) from old index $oldIndexForStep"
            $newSteps += $deploymentProcess.Steps[$oldIndexForStep]
        }
        elseif($oldStepCounter -eq $oldIndexForStep){
            Write-Host "--Hit old index for step at $oldIndexForStep, skipping $($deploymentProcess.Steps[$oldIndexForStep].Name) from old index $oldIndexForStep, adding $($deploymentProcess.Steps[$i+1].Name) at index $($i+1)"
            $oldStepCounter++
            $newSteps += $deploymentProcess.Steps[$oldStepCounter]
            $oldStepCounter++
        }
        else{
            Write-Host "--Adding step $($deploymentProcess.Steps[$oldStepCounter].Name) at index $i"
            $newSteps += $deploymentProcess.Steps[$oldStepCounter]
            $oldStepCounter++
        }
    }
    # Update steps to new order
    $deploymentProcess.Steps = $newSteps
    
    # Write out new step order (for debug)
    Write-Host "New step order:"
    foreach($step in $newSteps){
        Write-Host "$($step.Name)"
    }
    # Commit changes to process - uncomment to commit
    #Invoke-RestMethod -Method Put -Uri "$octopusURL/$($project.Links.DeploymentProcess)" -Headers $header -Body ($deploymentProcess | ConvertTo-Json -Depth 100)
}
else{
    Write-Host "New index for step is the same as existing index for step or step name not found, no steps moved."
}