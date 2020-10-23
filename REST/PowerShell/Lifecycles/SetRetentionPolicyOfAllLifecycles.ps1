$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

# Helpful notes:
# - Unit can be either of "Days" or "Items"
# - If ShouldKeepForever = True, QuantityToKeep should be 0 to keep all

# Choose release retention policy
# This could be applied to both the Lifecycle AND phases if configured.
$releaseRetentionPolicy = [PSCustomObject]@{
    Unit = "Days" 
    QuantityToKeep = 30
    ShouldKeepForever = $false
}

# Choose tentacle release retention policy
# This could be applied to both the Lifecycle AND phases if configured.
$tentacleRetentionPolicy = [PSCustomObject]@{
    Unit = "Days"
    QuantityToKeep = 30
    ShouldKeepForever = $false
}

# Should we update the Lifecycle retention policy, with the values specified above?
$UpdateLifecycleRetentionPolicy = $True 

# Should we update the retention policy in all phases found in the lifecycle, with the values specified above?
$UpdateRetentionPolicyInPhases = $True 

# Get Lifecycle records
$AllLifecycles = (Invoke-WebRequest $OctopusURL/api/lifecycles/all -Headers $header).content | ConvertFrom-Json 

# Loop through each lifecycle
foreach ($lifecycle in $AllLifecycles){

    Write-host "Working on lifecycle: [$($lifecycle.Name)]" -ForegroundColor Yellow
    # Update Lifecycle retention policy if configured.
    if($UpdateLifecycleRetentionPolicy -eq $True){
        Write-Host "`tModifying lifecycle retention policy for: [$($lifecycle.Name)]" -ForegroundColor DarkBlue
        $lifecycle.ReleaseRetentionPolicy = $releaseRetentionPolicy
        $lifecycle.TentacleRetentionPolicy = $tentacleRetentionPolicy
        
    }
    else {
        Write-host "Skipping lifecycle retention policy update for: [$($lifecycle.Name)] as UpdateLifecycleRetentionPolicy = False" -ForegroundColor Yellow
    }

    # Update Lifecycle's phases retention policy if configured.  
    if($UpdateRetentionPolicyInPhases -eq $True) {
        foreach ($phase in $lifecycle.Phases){
            Write-Host "`tModifying retention policy of phase: [$($phase.Name)] for Lifecyle: [$($lifecycle.Name)]" -ForegroundColor Blue
            $phase.ReleaseRetentionPolicy = $releaseRetentionPolicy
            $phase.TentacleRetentionPolicy = $tentacleRetentionPolicy
        }
    }
    else {
        Write-host "Skipping phase retention policy updates for: [$($lifecycle.Name)] as UpdateRetentionPolicyInPhases = False" -ForegroundColor Yellow
    }
    
    $body = $lifecycle | ConvertTo-Json -Depth 10

    Write-Host "Saving changes for lifecycle: [$($lifecycle.Name)]" -ForegroundColor Green
    Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/lifecycles/$($lifecycle.Id)" -Body $body -Headers $header
}