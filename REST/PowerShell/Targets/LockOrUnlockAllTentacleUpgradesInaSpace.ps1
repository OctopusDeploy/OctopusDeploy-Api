# =======================================================================
#      Lock or unlock Tentacle upgrades for all Tentacles in a Space     
# =======================================================================


$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "http://YOUR_OCTOPUS_URL"
$octopusAPIKey = "API-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$UpgradeLocked = $true # set to $true to lock or $false to unlock

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# Get machine list
$machines = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines/all" -Headers $header)

Foreach ($machine in $machines) {
    $currentMachine = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines/$($machine.Id)" -Headers $header)
    If ($currentMachine.Endpoint.TentacleVersionDetails.UpgradeLocked -ne $null) {
        $currentMachine.Endpoint.TentacleVersionDetails.UpgradeLocked = $UpgradeLocked

        # Update machine object
        Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/machines/$($machine.Id)" -Body ($currentMachine | ConvertTo-Json -Depth 10) -Headers $header
    }
}
