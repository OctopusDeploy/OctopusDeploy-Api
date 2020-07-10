# Octopus Url
$OctopusUrl = "https://your-octopus-url"

# API Key
$APIKey = "API-XXXXXXXXX"

# Space where machines exist
$spaceName = "Default" 

# List of machines you want to check who created
$machines = @("machineName1", "machineName2") 

$header = @{ "X-Octopus-ApiKey" = $APIKey }

Write-Host "Getting list of all spaces: $OctopusUrl/api/Spaces?skip=0&take=100000"
$spaceList = (Invoke-RestMethod "$OctopusUrl/api/Spaces?skip=0&take=100000" -Headers $header)
$space = $spaceList.Items | Where-Object { $_.Name -eq $spaceName} | Select-Object -First 1
$spaceId = $space.Id

Write-Host "Getting list of machines in space: $OctopusUrl/api/$spaceId/machines?skip=0&take=100000"
$spaceMachines = (Invoke-RestMethod "$OctopusUrl/api/$spaceId/machines?skip=0&take=100000" -Headers $header)

foreach ($machine in $machines) {
    $matchingMachine = $spaceMachines.Items | Where-Object { $_.Name -eq $machine} | Select-Object -First 1
    if($null -eq $matchingMachine) {
        Write-Host "No machine found matching name: $machine"
        continue
    }
    $machineId = $matchingMachine.Id
    
    Write-Host "Getting list of event entries regarding machine: ${machineId}"
    $machineCreatedEvents = (Invoke-RestMethod "$OctopusUrl/api/events?eventCategories=Created&regarding=$machineId&skip=0&take=100000" -Headers $header) 
    $machineCreatedItems = $machineCreatedEvents.Items | Sort Occurred
    $firstMachineCreatedEvent = $machineCreatedItems | Select-Object -First 1
    if($null -eq $firstMachineCreatedEvent) {
        Write-Host "No machine created event found for machine: $machine"
        continue
    }
    
    $username = $firstMachineCreatedEvent.Username
    $userId = $firstMachineCreatedEvent.UserId
    Write-Host "Machine $machine was created by: $username ($userId)"
}
