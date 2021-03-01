#Add-Type -Path 'C:\MyScripts\Newtonsoft.Json.dll'
Add-Type -Path 'C:\MyScripts\Octopus.Client.dll' 

$server = "YourServerURL"
$apikey = "API-KEY"

# Create endpoint and client
$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($server, $apikey)
$client = New-Object Octopus.Client.OctopusClient($endpoint)

# Get default repository and get space by name
#$repository = $client.ForSystem()
#$space = $repository.Spaces.FindByName("Second")

# Get space specific repository and get all projects in space
#$repo = $client.ForSpace($space)

# We need to grab the entire Lifecycle object as all changes to it must be saved as an entire complete Lifecycle object.
$lifecycle = $client.Repository.Lifecycles.FindByName("Prod") # Lifecycle name to add a phase to.
# We need the Environment-id to tell the phase which environment to associate with it.
$Environment = $client.Repository.Environments.FindByName(“Test").Id # Environment name to add to phase.


# Create new $phase object and add requisite values.
$phase = New-Object Octopus.Client.Model.PhaseResource
$phase.Name = "New Phase Name" # Rename what you want.
$phase.OptionalDeploymentTargets.Add($Environment)
$phase.MinimumEnvironmentsBeforePromotion = 0

# Phase's retention Policy
$phase.ReleaseRetentionPolicy = [Octopus.Client.Model.RetentionPeriod]::new(0,[Octopus.Client.Model.RetentionUnit]::Items) #Unlimmited Releases
#$phase.ReleaseRetentionPolicy = [Octopus.Client.Model.RetentionPeriod]::new(2,[Octopus.Client.Model.RetentionUnit]::Days) #2 days
$phase.TentacleRetentionPolicy = [Octopus.Client.Model.RetentionPeriod]::new(0,[Octopus.Client.Model.RetentionUnit]::Items)
#$phase.TentacleRetentionPolicy = [Octopus.Client.Model.RetentionPeriod]::new(10,[Octopus.Client.Model.RetentionUnit]::Days) #10 days

# Add this $phase object to our $lifecycle object.
$lifecycle.Phases.Add($phase)

# Modify the Lifecycle with our new $lifecycle object containing our new phase.
$client.Repository.Lifecycles.Modify($lifecycle)

