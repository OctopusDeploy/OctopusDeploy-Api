# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll'

$octopusURI = "http://localhost" # Your server address
$apiKey = 'API-IQW9QGGWJE5T4KFVQLL15PUY' # Get this from your profile
$projectId = "Projects-120" # The id of the project

$endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusURI, $apiKey 

$repository = new-object Octopus.Client.OctopusRepository $endpoint

Function Copy-Dictionary {
    param($source, $destination)

    foreach ($item in $source.GetEnumerator()) {
        if ($destination.ContainsKey($item.Key)) {
            continue
        }
        $destination.Add($item.Key, $item.Value)
    }
}

$project = $repository.Projects.Get($projectId)
$process = $repository.DeploymentProcesses.Get($project.DeploymentProcessId)

$step = $process.Steps | Select-Object -first 1
foreach ($action in $step.Actions) {
    $newStep = New-Object Octopus.Client.Model.DeploymentStepResource
    $newStep.Name = $action.Name
    $newStep.Condition = $step.Condition
    $newStep.StartTrigger = $step.StartTrigger
    $newStep.RequiresPackagesToBeAcquired = $step.RequiresPackagesToBeAcquired
    $newStep.Actions.Add($action)    
    
    Copy-Dictionary $action.Properties $newStep.Properties
    Copy-Dictionary $action.SensitiveProperties $newStep.SensitiveProperties
    Copy-Dictionary $step.Properties $newStep.Properties
    Copy-Dictionary $step.SensitiveProperties $newStep.SensitiveProperties

    $process.Steps.Add($newStep)
}

$process.Steps.Remove($step);

$repository.DeploymentProcesses.Modify($process);
