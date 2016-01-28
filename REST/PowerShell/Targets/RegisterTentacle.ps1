#Config
$OctopusAPIkey = "" #API Key to authenticate in Octopus
$OctopusURL = "" #Octopus server url

$TentacleURL = "" #Tentacle URL. Remember it must be https. i.e "https://localhost","http://192.168.1.12","Http://MyMachineFQDN"
$TentaclePort = "" #Port the Listening Tentacle will use to comunicate with the Octopus server
$TentacleThumbprint = "" #Tentacle Thumbprint
$TentacleName = "" #Tentacle name
$TentacleRoles = "" #Tentacle role. It can be a collection 
$EnvironmentIDs = "" #IDs of the Environments where the Tentacle will be registered. It can be a collection

##Process
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$body = @{ Endpoint = @{
                        CommunicationStyle = "TentaclePassive" #This will only work for Listening Tentacles
                        Thumbprint = $TentacleThumbprint
                        Uri = "$tentacleURL`:$TentaclePort/"
                        }
            EnvironmentIDs = @($EnvironmentIDs)
            Name = $TentacleName
            Roles = @($TentacleRoles)
            Status = "Unknown"
            IsDisabled = $false
        } | ConvertTo-Json -Depth 10

Invoke-RestMethod "$OctopusURL/api/machines" -Headers $header -Method Post -Body $body