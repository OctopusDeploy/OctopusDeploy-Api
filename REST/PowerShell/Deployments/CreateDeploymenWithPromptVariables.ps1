##CONFIG##
$apiKey = "Your API Key"
$OctopusURL = "Your Octopus URL"

$ProjectName = "Your Project Name"
$EnvironmentName = "Your Environment Name"

##PROCESS##
$Header =  @{ "X-Octopus-ApiKey" = $apiKey }

#Getting Environment and Project By Name
$Project = Invoke-WebRequest -Uri "$OctopusURL/api/projects/$ProjectName" -Headers $Header| ConvertFrom-Json

$Environment = Invoke-WebRequest -Uri "$OctopusURL/api/Environments/all" -Headers $Header| ConvertFrom-Json

$Environment = $Environment | ?{$_.name -eq $EnvironmentName}

#Getting Deployment Template to get Next version 
$dt = Invoke-WebRequest -Uri "$OctopusURL/api/deploymentprocesses/deploymentprocess-$($project.id)/template" -Headers $Header | ConvertFrom-Json 

#Creating Release
$ReleaseBody =  @{ Projectid = $Project.Id
            version = $dt.nextversionincrement } | ConvertTo-Json

$r = Invoke-WebRequest -Uri $OctopusURL/api/releases -Method Post -Headers $Header -Body $ReleaseBody | ConvertFrom-Json

#Getting task to get preview
$t = Invoke-WebRequest -Uri ($OctopusURL + $r.links.DeploymentTemplate) -Headers $Header | ConvertFrom-Json

#Preview holds the variables labeles and names.
$p = Invoke-WebRequest -Uri ($OctopusURL + $t.PromoteTo.links.Preview) -Headers $Header | ConvertFrom-Json

#Creating deployment and setting value to the only prompt variable I have on $p.Form.Elements. You're gonna have to do some digging if you have more variables
$DeploymentBody = @{ 
            ReleaseID = $r.Id #mandatory
            EnvironmentID = $Environment.id #mandatory
            FormValues = @{ # Here is where you declare all your Prompt variables. Browse $p.Form.Elements to see which ones are available and add an extra line on this array for each one.
                            "$($p.Form.Elements.name)" = "My Variable Value!"
            ForcePackageDownload="False"
            ForcePackageRedeployment="False"
            UseGuidedFailure="False"
                         }                             
          } | ConvertTo-Json
          
Invoke-WebRequest -Uri $OctopusURL/api/deployments -Method Post -Headers $Header -Body $DeploymentBody
