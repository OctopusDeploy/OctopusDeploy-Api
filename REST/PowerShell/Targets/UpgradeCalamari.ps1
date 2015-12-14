Add-Type -Path "" # Path to Newtonsoft.Json.dll 
Add-Type -Path "" # Path to Octopus.Client.dll 

$OctopusURL = "" #Octopus URL
$OctopusAPIKey = ""  # Octopus API Key
$MachineName = "" #Machine Display Name 

$endpoint = new-object Octopus.Client.OctopusServerEndpoint $OctopusURL,$OctopusAPIKey 
$repository = new-object Octopus.Client.OctopusRepository $endpoint 
$findmachine = $repository.Machines.FindByName("$MachineName") 
$machineid = $findmachine.id

$header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }

$body = @{ 
    Name = "UpdateCalamari" 
    Description = "Updating calamari on $MachineName" 
    Arguments = @{ 
        Timeout= "00:05:00" 
        MachineIds = @($machineId) #$MachinID could contain an array of machines too
    } 
} | ConvertTo-Json

Invoke-RestMethod $OctopusURL/api/tasks -Method Post -Body $body -Headers $header