$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-YOURKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"

# Get space Id
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

# e.g. "Interruptions-204". 
# You can get this ID from the deployment document like this -> /api/interruptions?regarding=[Deployment ID]
$InterruptionID = "Interruptions-145" 

$header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }

$body = @{Instructions= $null
            Notes = "Message"
            # Set this property to "Abort" to abort the deployment.
            # Omit the property completely for a failure guidance interruption.
            Result = "Proceed" 
            # If you wish to Exclude the machine from the deployment (in case of a rolling deploy), uncomment the line below.
            # Guidance = "Exclude" 
        } | ConvertTo-Json

# Take responsibility for the Intervention
Invoke-RestMethod "$OctopusURL/api/$($space.Id)/interruptions/$InterruptionID/responsible" -Method Put -Headers $header

#Approve/abort the intervention
Invoke-RestMethod "$OctopusURL/api/$($space.Id)/interruptions/$InterruptionID/submit" -Body $body -Method Post -Headers $header
