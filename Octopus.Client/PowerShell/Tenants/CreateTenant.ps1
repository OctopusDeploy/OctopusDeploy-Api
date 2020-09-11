
# NOTE: this script will fail if the Tenants feature is not enabled on your Octopus Server

# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-xxx' # Get this from your profile
$octopusURI = 'http://localhost' # Your Octopus Server address

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI, $apiKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint


$tagSetEditor = $repository.TagSets.CreateOrModify("Hosting")
$tagSetEditor.AddOrUpdateTag("On premises", "Hosted on site", [Octopus.Client.Model.TagResource+StandardColor]::DarkGreen)
$tagSetEditor.AddOrUpdateTag("Cloud", "Hosted in the cloud", [Octopus.Client.Model.TagResource+StandardColor]::LightBlue)
$tagSetEditor.Save()

$tagSet = $tagSetEditor.Instance


$project = $repository.Projects.FindByName("Multi tenant project")
$environment = $repository.Environments.FindByName("Dev")

$tenantEditor = $repository.Tenants.CreateOrModify("John")
$tenantEditor.WithTag($tagSet.Tags[0])
$tenantEditor.ConnectToProjectAndEnvironments($project, $environment)
$tenantEditor.Save()
