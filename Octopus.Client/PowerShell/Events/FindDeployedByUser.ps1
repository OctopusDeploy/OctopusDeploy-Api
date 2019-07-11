# You can this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/

cd C:\MyScripts\Octopus.Client
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-KEY' # Get this from your profile
$octopusURI = 'http://OctopusServer/' # Your server address

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

# This script searches the Events (Audit log) for events of Category Queued and looks into the RelatedDocumentIds field for further refining.
# This script will return the name of a user who started a deployment (queued), but you need to enter one or more of the following.
# 
# Properties of the RelatedDocumentIds for DeploymentQueued.
# Projects-342, Releases-965, Environments-1, ServerTasks-159414, Channels-362, ProjectGroups-1
#
# The easiest way to find a single result is by using the ServerTasks-ID in my example below. (Searching time can vary based on amount of events)

$serverTasksID = "ServerTasks-159414"

#Using lambda expression to filter events using the FindMany method
$repository.Events.FindMany(
    {param($e) if(($e.Category -match "Queued") -and ($e.RelatedDocumentIds -contains $serverTasksID))
        {
        #$True # Uncomment this to return the entire object.
        Write-Host "The account which :" $e.message ": Was :" $e.username
        }
    })
