# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-KEY' # Get this from your profile
$octopusURI = 'https://localhost' # Your server address
$stepName = '' # The name of the step you want to remove

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$projects = $repository.Projects.FindAll()

foreach ($project in $projects)  {
    $process = $repository.DeploymentProcesses.Get($project.DeploymentProcessId)
    $IndexOfStep = $process.Steps.Name.IndexOf($stepName)
    if($IndexOfStep -ne -1) {
        $process.Steps.RemoveAt($IndexOfStep)

    }
    else {
        Write-Host "'$stepName' does not exist in this project" -ForegroundColor Green
    }
    $repository.DeploymentProcesses.Modify($process)
} 
