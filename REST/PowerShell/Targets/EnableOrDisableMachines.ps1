$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Provide Space name
$spaceName = "Default"

# Provide list of machines to enable or disable
$machineNames = @("MyMachine1", "MyMachine2")

# Set this to $False to Disable machines, or $True to Enable the machines
$machinesEnabled = $true

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get all machines (paged)
$machines = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/machines" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    Write-Verbose "Found $($response.Items.Length) machines.";
    $machines += $response.Items
} while ($response.Links.'Page.Next')

# Get machines

foreach ($machineName in $machineNames) {
    $matchingMachines = @($machines | Where-Object { $_.Name -ieq $machineName })
    if ($null -eq $matchingMachines) {
        Write-Warning "Found no matching machines for $machineName, continuing"
    }
    if ($matchingMachines.Count -gt 1) {
        Write-Error "Found multiple machines matching name: $machineName. Don't know which machine to enable or disable!"
    }
    $machine = $matchingMachines | Select-Object -First 1

    # Enable/disable machine
    $machine.IsDisabled = !$machinesEnabled

    # Update machine
    Write-Verbose "Updating machine: $($machine.Name) ($($machine.Id)), IsDisabled: $(!$machinesEnabled)"
    Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/machines/$($machine.Id)" -Headers $header -Body ($machine | ConvertTo-Json -Depth 10)
}

