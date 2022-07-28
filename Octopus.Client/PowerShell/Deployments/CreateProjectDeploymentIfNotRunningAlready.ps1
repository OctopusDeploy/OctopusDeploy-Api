  

# You can get this dll from NuGet
# https://www.nuget.org/packages/Octopus.Client/
Add-Type -Path 'Octopus.Client.dll'

$octopusURL = 'http://youroctopusserver' # Your Octopus Server address
$apikey = 'API-xxxxx'  # Get this from your profile
$projectName = 'ChildProject' # The name of the project that you want to create a deployment for 
$environmentName = 'Development' # The environment you want to deploy to
$spaceName = "Default"  # The space that the $projectName is in

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint $octopusURL,$apikey 
$repository = New-Object Octopus.Client.OctopusRepository $endpoint
$Header =  @{ "X-Octopus-ApiKey" = $apiKey }

# Getting space
$spaces = (Invoke-WebRequest "$OctopusURL/api/spaces?skip=0" -Method Get -Headers $header -UseBasicParsing).content | ConvertFrom-Json
$spaceId = ($spaces.Items | Where-Object{($_.Name -eq $spaceName)}).Id

# Getting environment
$Environment = Invoke-WebRequest -Uri "$OctopusURL/api/Environments/all" -Headers $Header| ConvertFrom-Json
 
$Environment = $Environment | Where-Object{$_.name -eq $environmentName}

If($Environment.count -eq 0){
    throw "Environment not found: $environmentName"
}

# See if any running tasks for project
$tasks = (Invoke-WebRequest "$OctopusURL/api/tasks?skip=0&environment=$($environment.Id)&spaces=$spaceId&includeSystem=false" -Method Get -Headers $header -UseBasicParsing).content | ConvertFrom-Json

$tasksForProjAndEnv = ($tasks.Items | Where-Object{($_.IsCompleted -eq $false) -and ($_.Description.tolower() -like "*$($projectName.tolower())*")} |  Select-Object -First 1000)

if ((($tasksForProjAndEnv -is [array]) -and ($tasksForProjAndEnv.length -ge 2))  -or (($tasksForProjAndEnv -isnot [array]) -and ( $tasksForProjAndEnv))) {
    Write-output "Job already running, will not run: $projectName"
    exit
}

Write-output "Creating deployment for: $projectName"
    
#--- Will only continue if no running deployment for project.

# Getting Project
Try{
    $Project = Invoke-WebRequest -Uri "$OctopusURL/api/projects/$ProjectName" -Headers $Header -ErrorAction Ignore| ConvertFrom-Json
    }
Catch{
    Write-Error $_
    Throw "Project not found: $ProjectName"
}


# Getting Release - latest

$release = ((Invoke-WebRequest "$OctopusURL/api/projects/$($Project.Id)/releases" -Headers $Header).content | ConvertFrom-Json).items | Select-Object -First 1
If($release.count -eq 0){
    throw "No releases found for project: $ProjectName"
}

$deployment = new-object Octopus.Client.Model.DeploymentResource
$deployment.ReleaseId = $release.Id
$deployment.ProjectId = $release.ProjectId
$deployment.EnvironmentId = $environment.Id

# Create deployment
$repository.Deployments.Create($deployment)


