$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://YOUR-OCTOPUS-URL"
$octopusAPIKey = "API-XXX"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$spaceName = "Default"

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get projects for space
$projectList = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header

# Loop through projects
foreach ($project in $projectList)
{
    # Get project deployment process
    $deploymentProcess = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/deploymentprocesses/$($project.DeploymentProcessId)" -Headers $header

    # Get steps
    foreach ($step in $deploymentProcess.Steps)
    {
        # Check for the step being a script step that doesn't use a library step template
        if ($step.Actions.ActionType -eq "Octopus.Script" -and !$step.Actions.Properties.'Octopus.Action.Template.Id' )
        {           
                $extension = "ps1"; 
                switch($($step.Actions.properties.'Octopus.Action.Script.Syntax')){
                    "Bash"   { $extension = "sh"; break; }
                    "C#"     { $extension = "cs"; break; }
                    "F#"     { $extension = "fs"; break; }
                    "Python" { $extension = "py"; break; }
                 }
                
                # output script content to a file
                $step.Actions.properties.'Octopus.Action.Script.Scriptbody' | out-file "ProjectScripts/Scripts/$($project.Name)_$($step.Name)_$($step.Actions.Id).$($extension)"                
        }
    }
}
