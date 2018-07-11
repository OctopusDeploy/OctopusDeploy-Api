Add-Type -Path "C:\Tools\Octopus.Client.dll"

$apikey = ''
$octopusURI = ''

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI, $apiKey
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$tagset = $repository.TagSets.FindByName("MyTagset")

$newtag = New-Object Octopus.Client.Model.TagResource

$newtag.Name = "MyNewTag"
$newtag.Color = "#232323"
#Modify any other properties of $newTag here

$tagset.Tags.Add($newtag) #You might wanna double check that a tag with that name doesn't exist here.
