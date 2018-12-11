# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-MCPLE1AQM2VKTRFDLIBMORQHBXA' # Get this from your profile
$octopusURI = 'http://localhost' # Your server address
$stepName = 'Raygun - Register Deployment' # The name of the step you want to remove

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
        Write-Host "'$stepName' does not exist in this project"
    }
    $repository.DeploymentProcesses.Modify($process)
} 
