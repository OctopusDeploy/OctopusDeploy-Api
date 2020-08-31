$APIKey = "API-XXXXX" # Requires an API Key, preferably as a sensitive variable

$OctopusUrl = $OctopusParameters["Octopus.Web.ServerUri"]
$ProjectId = $OctopusParameters["Octopus.Project.Id"]
$ChannelId = $OctopusParameters["Octopus.Release.Channel.Id"]
$OctopusEnvironmentName = $OctopusParameters["Octopus.Environment.Name"]
$OctopusEnvironmentId = $OctopusParameters["Octopus.Environment.Id"]
$OctopusSpaceId = $OctopusParameters["Octopus.Space.Id"]

$header = @{ "X-Octopus-ApiKey" = $APIKey }
$OctopusChannels = (Invoke-RestMethod "$OctopusUrl/api/$OctopusSpaceId/channels/$ChannelId" -Headers $header)

$LifeCycleId = $OctopusChannels.LifecycleId
if ([string]::IsNullOrWhitespace($LifeCycleId))
{
	Write-Host "LifecycleId is null, presumably due to Default Channel"
    $OctopusProject = (Invoke-RestMethod "$OctopusUrl/api/$OctopusSpaceId/projects/$ProjectId" -Headers $header)
	$LifeCycleId = $OctopusProject.LifecycleId
}
if ([string]::IsNullOrWhitespace($LifeCycleId))
{
	throw "Couldnt find LifeCycleId!"
}

Write-Host "LifecycleId: " $LifeCycleId
$OctopusLifecycles = (Invoke-RestMethod "$OctopusUrl/api/$OctopusSpaceId/lifecycles/$LifeCycleId" -Headers $header)
$OctopusPhases = $OctopusLifecycles.Phases
foreach($phase in $OctopusPhases){
	foreach($environment in $phase.OptionalDeploymentTargets){
		if ($OctopusEnvironmentId -eq $environment){
			Write-Highlight "Environment: $($OctopusEnvironmentName)"
            Write-Highlight "Phase Name: $($phase.Name)"
            Exit 0
		}
	}
}