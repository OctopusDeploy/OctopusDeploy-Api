##CONFIG
$apikey = 'API-XXXXXXXXXXXXXXXXXXXXXXXXXX' # Get this from your profile
$octopusURI = 'https://octopus.url' # Your server address
$Role = "MyTargetRole" #The Role you want to look for
$OctoClientDll = 'C:\Program Files\Octopus Deploy\Tentacle\Octopus.Client.dll' #If you don't have this DLL on disc, you can download it from https://www.nuget.org/packages/Octopus.Client/

##EXECUTION
Add-Type -Path $OctoClientDll

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURI,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint

$allProjects = $repository.Projects.GetAll()

"Looking for steps with the role $($Role) in them..."

foreach($project in $allProjects){
    $dp = $repository.DeploymentProcesses.Get($project.Links.DeploymentProcess)

    foreach ($step in $dp.Steps){
        if($step.properties.'Octopus.Action.TargetRoles' -and ($step.properties.'Octopus.Action.TargetRoles'.Value.Split(',') -Icontains $Role )){
            "Step [$($step.Name)] from project [$($project.Name)] is using the role [$($Role )]"
        }
    }
}
