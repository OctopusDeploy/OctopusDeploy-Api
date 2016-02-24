##CONFIG##

$apiKey = "" #Octopus API Key
$OctopusURL = "" #Octopus URL
 
$ProjectName = "" #project name
$EnvironmentName = "" #environment name

##PROCESS##

$Header =  @{ "X-Octopus-ApiKey" = $apiKey }
 
#Getting Environment and Project By Name
$Project = Invoke-WebRequest -Uri "$OctopusURL/api/projects/$ProjectName" -Headers $Header| ConvertFrom-Json
 
$Environment = Invoke-WebRequest -Uri "$OctopusURL/api/Environments/all" -Headers $Header| ConvertFrom-Json
 
$Environment = $Environment | ?{$_.name -eq $EnvironmentName}

#Getting Deployment Template to get Next version 
$dt = Invoke-WebRequest -Uri "$OctopusURL/api/deploymentprocesses/deploymentprocess-$($Project.id)/template" -Headers $Header | ConvertFrom-Json 
 
#Creating Release
$ReleaseBody =  @{ Projectid = $Project.Id
            version = $dt.nextversionincrement } | ConvertTo-Json
 
$r = Invoke-WebRequest -Uri $OctopusURL/api/releases -Method Post -Headers $Header -Body $ReleaseBody | ConvertFrom-Json
 
#Creating deployment
$DeploymentBody = @{ 
            ReleaseID = $r.Id #mandatory
            EnvironmentID = $Environment.id #mandatory
          } | ConvertTo-Json
          
$d = Invoke-WebRequest -Uri $OctopusURL/api/deployments -Method Post -Headers $Header -Body $DeploymentBody