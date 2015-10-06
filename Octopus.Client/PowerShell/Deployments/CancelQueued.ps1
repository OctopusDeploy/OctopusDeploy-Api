# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-xxx' # Get this from your profile
$octopusURI = 'http://localhost' # Your Octopus Server address

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$QueuedTasksEvaluator = {  
  param ($t) 
  return $t.State -eq "Queued" 
}
 
foreach ($queued in $repository.Tasks.FindMany($QueuedTasksEvaluator))
{
    $repository.Tasks.Cancel($queued)
}