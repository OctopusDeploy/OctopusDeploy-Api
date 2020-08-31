# Octopus Url
$OctopusUrl = "https://your-octopus-url"

# API Key
$APIKey = "API-XXXXXXXXX"

# Space where machines exist
$spaceName = "Default" 

# Should we delete machines that are disabled?
$includeDisabledMachines = $false

# Search parameter to limit machines which are checked
$machinePartialName = ""

$header = @{ "X-Octopus-ApiKey" = $APIKey }

Write-Host "Getting list of all spaces: $OctopusUrl/api/Spaces?skip=0&take=100000"
$spaceList = (Invoke-RestMethod "$OctopusUrl/api/Spaces?skip=0&take=100000" -Headers $header)
$space = $spaceList.Items | Where-Object { $_.Name -eq $spaceName} | Select-Object -First 1
$spaceId = $space.Id

$machineCheckUrl = "$OctopusUrl/api/$spaceId/machines?partialName=$machinePartialName&roles=&isDisabled=$includeDisabledMachines&healthStatuses=Unavailable&healthStatuses=Unknown&skip=0&take=100000"
Write-Host "Getting list of unavailable machines in space: $machineCheckUrl"
$spaceMachines = (Invoke-RestMethod $machineCheckUrl -Headers $header)

foreach ($machine in $spaceMachines.Items) {
    $machineName = $machine.Name
    $machineId = $machine.Id
    Write-Host "Found machine: $machineName ($machineId) to delete"
    
    $response = Invoke-RestMethod -Uri "$OctopusUrl/api/$spaceID/machines/$machineId" -Method Delete -Headers $header
    Write-Host "Deleted Machine $machineName ($machineId)"
}
