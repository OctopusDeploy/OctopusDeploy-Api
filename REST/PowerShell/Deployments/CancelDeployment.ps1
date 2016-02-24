##CONFIG##

$OctopusURL = "" #Octopus URL
$OctopusAPIKey = "" #Octopus API Key

$ProjectName = "" #Name of the project that owns the deployment
$EnvironmentName = "" #Name of the environment where the deployment is taking place


##PROCESS##

$header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }

#Get dashboard to get latest deployments
$dashboard = (Invoke-WebRequest "$OctopusURL/api/dashboard" -Method Get -Headers $header).content | ConvertFrom-Json

#Get the Environment and Project to filter later
$Environment = $dashboard.Environments | ?{$_.name -eq $EnvironmentName}
$Project = $dashboard.Projects | ?{$_.name -eq $ProjectName}

#Get the deployment
$Deployment = $dashboard.Items | ?{($_.ProjectID -eq $Project.Id) -and ($_.EnvironmentID -eq $Environment.id)} | sort -Descending -Property Created |select -First 1


#Cancel the task asociated with the deployment
Invoke-WebRequest ("$OctopusURL" + $Deployment.links.Task + "/cancel") -Method Post -Headers $header