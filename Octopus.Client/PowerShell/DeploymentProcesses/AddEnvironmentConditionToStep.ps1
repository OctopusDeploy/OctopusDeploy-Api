# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll'

$apikey = 'API-KEY' # Get this from your profile
$octopusURI = 'https://localhost' # Your server address
$spaceName = '' # Space for projects
$stepToModify = '' # name of the step you wish to add environment conditions to
$environmentNames = @('')  # List of Environment names you wish to add as a condition the step to.

# Create endpoint and client
$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI, $apikey
$client = New-Object Octopus.Client.OctopusClient $endpoint

$repository = $client.ForSystem()

# Get space specific repository and get all projects in space
$space = $repository.Spaces.FindByName($spaceName)
$repositoryForSpace = $client.ForSpace($space)
$projects = $repositoryForSpace.Projects.GetAll()
$environments = $repositoryForSpace.Environments.GetAll()

foreach ($project in $projects) {
    $projectName = $project.Name
    Write-Host "Working on project: $projectName"

    # Get Deployment process for project
    $process = $repositoryForSpace.DeploymentProcesses.Get($project.DeploymentProcessId)
    
    # Get step to modify
    $step = $process.Steps | Where-Object {$_.Name -eq $stepToModify} | Select-Object -First 1

    if($null -ne $step) {

        # get action which matches step name
        $action = $step.Actions | Where-Object {$_.Name -eq $stepToModify} | Select-Object -First 1

        if($null -ne $action) {
            # Get each environmentid to add to the step
            foreach($envName in $environmentNames) {
                $envId = $environments | Where-Object {$_.Name -eq $envName} | Select-Object -First 1 -ExpandProperty Id
                $added = $action.Environments.Add($envId)
                if($added) {
                    Write-Host "Added Environment condition for '$envName' to Step '$stepToModify' in Project: '$projectName'."
                }
                else {
                    Write-Warning "Didn't add Environment condition for '$envName' to Step '$stepToModify' in Project: '$projectName', perhaps its already there?"
                }
            }
        }
    }

    # Update deployment process
    Write-Host "Saving $projectName's deployment process."
    $repositoryForSpace.DeploymentProcesses.Modify($process) | Out-Null
}
