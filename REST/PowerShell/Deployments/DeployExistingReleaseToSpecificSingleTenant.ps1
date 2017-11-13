##CONFIG##

$apiKey = "" #Octopus API Key
$OctopusURL = "" #Octopus URL
 
$ProjectName = "" #project name
$EnvironmentName = "" #environment name
$TenantID = "" #tenant ID, can be found in /api/tenants

$ReleaseVersion = "" #Version of the release you want to deploy. Put 'Latest' if you want to deploy the latest version without having to know its number.

##PROCESS##

$Header =  @{ "X-Octopus-ApiKey" = $apiKey }
 
#Getting Project
Try{
    $Project = Invoke-WebRequest -Uri "$OctopusURL/api/projects/$ProjectName" -Headers $Header -ErrorAction Ignore| ConvertFrom-Json
    }
Catch{
    Write-Error $_
    Throw "Project not found: $ProjectName"
}

#Getting environment
$Environment = Invoke-WebRequest -Uri "$OctopusURL/api/Environments/all" -Headers $Header| ConvertFrom-Json
 
$Environment = $Environment | ?{$_.name -eq $EnvironmentName}

If($Environment.count -eq 0){
    throw "Environment not found: $EnvironmentName"
}

#Getting machine
$tenant = Invoke-WebRequest -Uri "$OctopusURL/api/Tenants/$TenantID" -Headers $Header| ConvertFrom-Json

If($tenant.count -eq 0){
    throw "Tenant not found: $TenantID"
}

#Getting Release

If($ReleaseVersion -eq "Latest"){
    $release = ((Invoke-WebRequest "$OctopusURL/api/projects/$($Project.Id)/releases" -Headers $Header).content | ConvertFrom-Json).items | select -First 1
    If($release.count -eq 0){
        throw "No releases found for project: $ProjectName"
    }
}
else{
    Try{
    $release = (Invoke-WebRequest "$OctopusURL/api/projects/$($Project.Id)/releases/$ReleaseVersion" -Headers $Header).content | ConvertFrom-Json
    }
    Catch{
        Write-Error $_    
        throw "Release not found: $ReleaseVersion"    
    }
}
 
#Creating deployment
$DeploymentBody = @{ 
            ReleaseID = $release.Id
            EnvironmentID = $Environment.id
            TenantID = $tenant.id
          } | ConvertTo-Json
          
$d = Invoke-WebRequest -Uri $OctopusURL/api/deployments -Method Post -Headers $Header -Body $DeploymentBody
