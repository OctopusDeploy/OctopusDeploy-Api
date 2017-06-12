###CONFIG###

# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/

Add-Type -Path .\Octopus.Client.dll 

$apikey = "" # Get this from your profile
$octopusURI = "" # Your server address

$Description = "Health check started from Powershell script"
$TimeOutAfterMinutes = 5
$MachineTimeoutAfterMinutes = 5

#Choose either A or B by uncommenting the variables below each description

# A) Run on all machines on a single Environment by ID
#$EnvironmentID = "Environments-1"
#$MachineIds = $null

# B) Run on many machines by ID
#$EnvironmentID = $null
#$MachineIds = "Machines-1","Machines-2"


###PROCESS###

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$repository.Tasks.ExecuteHealthCheck($Description,$TimeOutAfterMinutes,$MachineTimeoutAfterMinutes,$EnvironmentID,$MachineIds)