# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-MCPLE1AQM2VKTRFDLIBMORQHBXA' # Get this from your profile
$octopusURI = 'http://localhost' # Your server address

$projectName = "Demo Project" # Name of your project
$roleToRemove = "Demo-role" # Role to remove (case sensitive)

$endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = new-object Octopus.Client.OctopusRepository $endpoint

$project = $repository.Projects.FindByName($projectName)

$deploymentProcess = $repository.DeploymentProcesses.Get($project.DeploymentProcessId)

foreach ($step in $deploymentProcess.Steps)
{
    [System.Collections.ArrayList]$roles = $step.Properties.'Octopus.Action.TargetRoles'.Split(",")
    If($roles -contains $roleToRemove){
        $roles.Remove($roleToRemove)
        $step.Properties.'Octopus.Action.TargetRoles' = $roles -join ","
    }
}

$repository.DeploymentProcesses.Modify($deploymentProcess)
