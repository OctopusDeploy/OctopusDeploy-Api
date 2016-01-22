# Data
$OctopusURL = "" #Octopus Root URL
$OctopusAPIKey = "" #Your Octopus API Key
$MachineID = "" #The ID of the machine you want to delete. e.g "Machines-1"

# Delete function
Function Delete-OctopusTarget([string]$ID) {
   return Invoke-RestMethod -Uri "$OctopusUrl/api/machines/$ID`?apiKey=$OctopusApiKey" -Method Delete
}

# Invoke delete function
Delete-OctopusTarget -ID $MachineID




