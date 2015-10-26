$OctopusURL = ""

$OctopusAPIKey = ""

$header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }

$machineId = "" #ID of the machine you want to check health on

$body = @{
    Name = "Health"
    Description = "Checking health of $machineId"
    Arguments = @{
        Timeout= "00:05:00"
        MachineIds = @($machineId)        
    }
} | ConvertTo-Json

Invoke-RestMethod $OctopusURL/api/tasks -Method Post -Body $body -Headers $header