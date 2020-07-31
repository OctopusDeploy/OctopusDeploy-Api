# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-xxxxx' # Get this from your profile
$octopusURI = 'https://xxxxx' # Your Octopus Server address

$runbookId = "Runbooks-1" # Get this from /api/runbooks
$runbookSnapshotId = "RunbookSnapshots-1" # Get this from /api/runbookSnapshots
$environmentId = "Environments-1" # Get this from /api/environments
$tenantId = "Tenant-1" # Get this from /api/tenants
$spaceName = "Default"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

# Find Space
$space = $repository.Spaces.FindByName($spaceName)
$repository = New-Object -TypeName Octopus.Client.OctopusRepository $endpoint, ([Octopus.Client.RepositoryScope]::ForSpace($space))


$runbook = $repository.RunbookSnapshots.Get($runbookSnapshotId)
$deployment = New-Object Octopus.Client.Model.RunbookRunResource
$deployment.RunbookId = $runbookId
$deployment.RunbookSnapshotId = $runbookSnapshotId
$deployment.EnvironmentId = $environmentId
$deployment.TenantId = $tenantId

$repository.RunbookRuns.Create($deployment)