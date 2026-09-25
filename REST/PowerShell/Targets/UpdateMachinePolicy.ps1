$ErrorActionPreference = "Stop";

  # Define working variables
  $octopusURL = "https://mysite.octopus.app"
  $octopusAPIKey = "API-MYAPIKEY"
  $header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
  $spaceName = "default"
  $machineNames = @("machine1", "machine2", "machine3")
  $machinePolicyName = "mypolicyname"

  # Get space
  $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

  # Get all machines
  $allMachines = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machines/all" -Headers $header

  # Get specified machine policy
  $machinePolicy = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/machinepolicies/all" -Headers $header) | Where-Object { $_.Name -eq $machinePolicyName }

  # Update each machine
  foreach ($machineName in $machineNames) {
      $machine = $allMachines | Where-Object {$_.Name -eq $machineName}

      if ($null -eq $machine) {
          Write-Warning "Machine not found: $machineName — skipping"
          continue
      }

      Write-Host "Updating machine policy for: $machineName"
      $machine.MachinePolicyId = $machinePolicy.Id
      Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/machines/$($machine.Id)" -Body ($machine | ConvertTo-Json -Depth 10) -Headers $header
  }
