#Script written to fix http://help.octopusdeploy.com/discussions/problems/48848

##CONFIG##
$OctopusAPIkey = "" #Octopus API Key
$OctopusURL = "" #Octopus root url
$ProjectName = "" #Name of the project

##PROCESS##

$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$allprojects = (Invoke-WebRequest $OctopusURL/api/projects/all -Headers $header).content | ConvertFrom-Json 

$project = $allprojects | ?{$_.name -eq $ProjectName}

If($project -ne $null){
    $project.AutoCreateRelease = $false
    $project.ReleaseCreationStrategy.ReleaseCreationPackageStepId = ""
    $project.ReleaseCreationStrategy.ChannelId = $null
    $project.VersioningStrategy.DonorPackageStepId = $null
    $Project.VersioningStrategy.Template = "#{Octopus.Version.LastMajor}.#{Octopus.Version.LastMinor}.#{Octopus.Version.NextPatch}"

    $projectJson = $project | ConvertTo-Json

    Invoke-WebRequest $OctopusURL/api/projects/$($project.id) -Method Put -Headers $header -Body $projectJson
}

Else{
    Write-Error "Project [$ProjectName] not found in $OctopusURL"
}