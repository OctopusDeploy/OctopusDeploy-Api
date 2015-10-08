# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = '' #Your API Key
$octopusURI = '' # Your server address

$endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = new-object Octopus.Client.OctopusRepository $endpoint

[System.DateTimeOffset]$after = "10/7/2015"
[System.DateTimeOffset]$before = "10/8/2015"

#Using lambda expression to filter events using the FindMany method
$repository.Events.FindMany(
    {param($e) if(($e.Occurred -gt $after) -and ($e.Occurred -lt $before)){
        $true
        }
    })