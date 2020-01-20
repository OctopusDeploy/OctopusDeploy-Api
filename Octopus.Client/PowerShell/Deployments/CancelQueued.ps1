$apikey = 'XXXXXX' # Get this from your profile
$OctopusUrl = 'https://OctopusURL/' # Your Octopus Server address
$spaceName = "Default" # Name of the Space
$projectId = "ProjectID" # Get this from the Spaces URL

# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/

Add-Type -Path 'Octopus.Client.dll'

# Set up endpoint and repository
$endpoint = new-object Octopus.Client.OctopusServerEndpoint $OctopusUrl, $APIKey
$repository = new-object Octopus.Client.OctopusRepository $endpoint

# Find Space
$space = $repository.Spaces.FindByName($spaceName)
$repository = New-Object -TypeName Octopus.Client.OctopusRepository $endpoint, ([Octopus.Client.RepositoryScope]::ForSpace($space))

# Kill Tasks
$deployments = $repository.Deployments.FindAll() 
$queued = $repository.Tasks.FindAll() | Where-Object {$_.State -eq "Queued" -and $_.HasBeenPickedUpByProcessor -eq $false}
foreach ($task in $queued)
{
    Write-Output "Killing task $($task.Id)"
    $repository.Tasks.Cancel($task)
}
