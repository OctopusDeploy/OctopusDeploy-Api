# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-MCPLE1AQM2VKTRFDLIBMORQHBXA' # Get this from your profile
$octopusURI = 'http://localhost' # Your server address

$endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = new-object Octopus.Client.OctopusRepository $endpoint

$project = $repository.Projects.FindByName("Demo Project") #The name of your project

$deploymentProcess = $repository.DeploymentProcesses.Get($project.DeploymentProcessId)

foreach ($step in $deploymentProcess.Steps)
{
  $step.Properties.'Octopus.Action.TargetRoles' = "demo-role" # The role this step will be scoped to
}
$repository.DeploymentProcesses.Modify($deploymentProcess)
