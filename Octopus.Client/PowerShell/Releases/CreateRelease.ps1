# You can get this dll from your Octopus Server/Tentacle installation directory or from
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll' 

$apikey = 'API-MCPLE1AQM2VKTRFDLIBMORQHBXA' # Get this from your profile
$octopusURI = 'http://localhost' # Your server address

$projectId = "Projects-1" # Get this from /api/projects

$endpoint = new-object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = new-object Octopus.Client.OctopusRepository $endpoint

$project = $repository.Projects.Get($projectId)
$process = $repository.DeploymentProcesses.Get($project.DeploymentProcessId)
$channel = $repository.Channels.FindByName($project,"Default") #Provide a valid channel
$template = $repository.DeploymentProcesses.GetTemplate($process,$channel)

$release = new-object Octopus.Client.Model.ReleaseResource
$release.Version = $template.NextVersionIncrement
$release.ProjectId = $project.Id

foreach ($package in $template.Packages)
{
    $selectedPackage = new-object Octopus.Client.Model.SelectedPackage
    $selectedPackage.ActionName = $package.ActionName
    $selectedPackage.PackageReferenceName = $package.PackageReferenceName
    $selectedPackage.Version = $package.VersionSelectedLastRelease # Select a new version if you know it
    $release.SelectedPackages.Add($selectedPackage)
}

$repository.Releases.Create($release, $false) # Pass in $true if you want to ignore channel rules
