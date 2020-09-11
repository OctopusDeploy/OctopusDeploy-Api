# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll'

$apikey = 'API-xx' # Get this from your profile
$octopusURI = 'http://octopus' # Your Octopus Server address

$projectName = "Web" # Name of the project to promote
$fromEnvironmentName = "Dev" # Name of the environment to promote from
$toEnvironmentName = "Staging" # Name of the environment to promote to

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$project = $repository.Projects.FindByName($projectName)
$environment = $repository.Environments.FindByName($fromEnvironmentName)
$toEnvironment = $repository.Environments.FindByName($toEnvironmentName)

$dashboard = $repository.Dashboards.GetDynamicDashboard($project.Id, $environment.Id)
$currentDeploymentInTest = $dashboard.Items | ? {$_.IsCurrent} | Select-Object -First 1

$promotedDeployment = New-Object Octopus.Client.Model.DeploymentResource
$promotedDeployment.EnvironmentId = $toEnvironment.Id
$promotedDeployment.ChannelId = $currentDeploymentInTest.ChannelId
$promotedDeployment.ProjectId = $currentDeploymentInTest.ProjectId
$promotedDeployment.ReleaseId = $currentDeploymentInTest.ReleaseId

$repository.Deployments.Create($promotedDeployment)
