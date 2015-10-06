# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-xxx' # Get this from your profile
$octopusURI = 'http://localhost' # Your Octopus Server address

$projectId = "Projects-x" # Get this from /api/projects

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI, $apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$deployments = $repository.Deployments.FindAll(@($projectId), @()) 
$queued = $repository.Tasks.FindMany({ param ($t) return $t.State -eq "Queued" })
foreach ($task in $queued)
{
    if($deployments.Items.Exists({param ($t) return $t.TaskId -eq $task.Id})) {
        $repository.Tasks.Cancel($task)
    }    
}
