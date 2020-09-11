# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
#Add-Type -Path 'Octopus.Client.dll' 

$apikey = '' # Get this from your profile
$octopusURI = '' # Your Octopus Server address

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

#Creating lifecycle
$lifecycle = New-Object Octopus.Client.Model.LifecycleResource
$lifecycle.Name = '' #Name of the lifecycle

#Default Retention Policy
$lifecycle.ReleaseRetentionPolicy = [Octopus.Client.Model.RetentionPeriod]::new(0,[Octopus.Client.Model.RetentionUnit]::Items) #Unlimmited Releases
#$lifecycle.ReleaseRetentionPolicy = [Octopus.Client.Model.RetentionPeriod]::new(2,[Octopus.Client.Model.RetentionUnit]::Days) #2 days
$lifecycle.TentacleRetentionPolicy = [Octopus.Client.Model.RetentionPeriod]::new(0,[Octopus.Client.Model.RetentionUnit]::Items)
#$lifecycle.TentacleRetentionPolicy = [Octopus.Client.Model.RetentionPeriod]::new(10,[Octopus.Client.Model.RetentionUnit]::Days) #10 days

#Creating Phase
$phase = New-Object Octopus.Client.Model.PhaseResource

$phase.Name = "Dev" #Name of the phase
$phase.OptionalDeploymentTargets.Add("Environments-1") #Adding optional Environment to phase
#$phase.AutomaticDeploymentTargets.Add("Environments-30") #Automatic Environment
$phase.MinimumEnvironmentsBeforePromotion = 0

#Phase's retention Policy
$phase.ReleaseRetentionPolicy = [Octopus.Client.Model.RetentionPeriod]::new(0,[Octopus.Client.Model.RetentionUnit]::Items) #Unlimmited Releases
#$phase.ReleaseRetentionPolicy = [Octopus.Client.Model.RetentionPeriod]::new(2,[Octopus.Client.Model.RetentionUnit]::Days) #2 days
$phase.TentacleRetentionPolicy = [Octopus.Client.Model.RetentionPeriod]::new(0,[Octopus.Client.Model.RetentionUnit]::Items)
#$phase.TentacleRetentionPolicy = [Octopus.Client.Model.RetentionPeriod]::new(10,[Octopus.Client.Model.RetentionUnit]::Days) #10 days

#Adding phase to new lifecycle
$lifecycle.Phases.Add($phase)

#Saving new lifecycle to DB
$repository.Lifecycles.Create($lifecycle)