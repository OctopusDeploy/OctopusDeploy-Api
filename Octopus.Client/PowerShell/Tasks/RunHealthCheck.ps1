# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path .\Octopus.Client.dll 

$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$spaceName = "Default"
$Description = "Health check started from Powershell script"
$TimeOutAfterMinutes = 5
$MachineTimeoutAfterMinutes = 5

# Choose an Environment, a set of machine names, or both.
$EnvironmentName = ""
$MachineNames = @()

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL, $octopusAPIKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$client = New-Object Octopus.Client.OctopusClient $endpoint

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Get EnvironmentId
    $EnvironmentID = $null
    if([string]::IsNullOrWhiteSpace($EnvironmentName) -eq $False) 
    {
        $EnvironmentID = $repositoryForSpace.Environments.FindByName($EnvironmentName).Id
    }
    
    # Get MachineIds
    $MachineIds = $null
    if($MachineNames.Count -gt 0)
    {
        $MachineIds = ($repositoryForSpace.Machines.GetAll() | Where-Object {$MachineNames -contains $_.Name} | Select-Object -ExpandProperty Id) -Join ", "
    }
    
    # Execute health check
    $repositoryForSpace.Tasks.ExecuteHealthCheck($Description,$TimeOutAfterMinutes,$MachineTimeoutAfterMinutes,$EnvironmentID,$MachineIds)
}
catch
{
    Write-Host $_.Exception.Message
}