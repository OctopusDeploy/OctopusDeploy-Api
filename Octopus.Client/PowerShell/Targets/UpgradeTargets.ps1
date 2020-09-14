# Load octopus.client assembly
Add-Type -Path "path\to\Octopus.Client.dll"

# Octopus variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$spaceName = "default"
$machineNames = @("MyMachine")

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Get machines
    $machines = @()
    foreach ($machineName in $machineNames)
    {
        # Get machine
        $machine = $repositoryForSpace.Machines.FindByName($machineName)
        $machines += $machine.Id
    }

    # Create new task resource
    $task = New-Object Octopus.Client.Model.TaskResource
    $task.Name = "Upgrade"
    $task.Description = "Upgrade machines"
    $task.Arguments.Add("MachineIds", $machines)    
    
    # Execute
    $repositoryForSpace.Tasks.Create($task)   
}
catch
{
    Write-Host $_.Exception.Message
}