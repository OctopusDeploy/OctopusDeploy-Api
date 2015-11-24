$OctopusURL = "" #Octopus server URL
$OctopusAPIKey = "" #Octopus API Key
$InterruptionID = "" # i.e "Interruptions-204". You can get this ID from the deployment document like this -> /api/interruptions?regarding=[Deployment ID]

$header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }

$body = @{Instructions= ""
            Notes = "Message" #message 
            Result="Proceed" #Set this property to "Abort" to abort the deployment           
        } | ConvertTo-Json

#Take responsability for the Intervention
Invoke-RestMethod "$OctopusURL/api/interruptions/$InterruptionID/responsible" -Method Put -Headers $header

#Approve/abort the intervention
Invoke-RestMethod "$OctopusURL/api/interruptions/$InterruptionID/submit" -Body $body -Method Post -Headers $header
