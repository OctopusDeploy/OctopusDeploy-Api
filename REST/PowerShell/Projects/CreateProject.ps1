# ==================================================================================================================
# This script creates a standard Project on the specified Octopus Server.
# To make the new Project Git-enabled (config-as-code), navigate to the new Project URL > Settings > Version Control
# ==================================================================================================================

$ErrorActionPreference = "Stop";

# ====== BYPASS PROMPTS? ======
$BypassPrompts = $false # Set to $true if you wish to predefine your parameters


# ====== PARAMETERS ======
If ($BypassPrompts) {
	
	# === Predefined Parameters (Optional) ===
    $OctopusURL = "http://YOUR_OCTOPUS_URL.bla"
    $OctopusAPIKey = "API-XXXXXXXXXXXXXXXXXX"
    $SpaceId = "Spaces-XX"
    $ProjectName = "My Project"
    $ProjectDescription = "My Description"
    $ProjectGroupName = "Default Project Group"
    $LifecycleName = "Default Lifecycle"
}

If (!$BypassPrompts) {
	
	# === Prompted Parameters ===
	$OctopusAPIKey = (Read-Host "Enter your Octopus API key (example: `"API-XXXXXXXXXXXXXXXXXX`")").trim('"')
	$OctopusURL = (Read-Host "Enter your Octopus Instance URL with no trailing slash (i.e. `"http://YOUR_OCTOPUS_URL.bla`")").trim('"')
	$SpaceId = (Read-Host "Enter the SpaceId where the Library Variable Set resides (example: `"Spaces-1`")").trim('"')
	$ProjectName = (Read-Host "Enter a name for your new Project (example: `"My Project`")").trim('"')
	$ProjectDescription = (Read-Host "Enter a description for your new Project (example: `"My Description`")").trim('"')
	$ProjectGroupName = (Read-Host "Enter the name of an existing Project Group in `"$($SpaceId)`" for your new Project (example: `"Default Project Group`")").trim('"')
	$LifecycleName = (Read-Host "Enter the name of an existing Lifecycle in `"$($SpaceId)`" for your new Project (example: `"Default Lifecycle`")").trim('"')
}

$Header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }


# ====== SCRIPT BODY ======
# Try to GET the ProjectGroupId for $ProjectGroupName
Try {
    $ProjectGroup = (Invoke-RestMethod -Method GET "$($OctopusURL)/api/$($SpaceId)/ProjectGroups/all" -Headers $Header) | Where-Object {$_.Name -eq $ProjectGroupName}
    If (!$ProjectGroup) {throw}
}
Catch {
    Write-Warning "Unable to find a ProjectGroupId for the Project Group Name `"$($ProjectGroupName)`" via `"$($OctopusURL)/api/$($SpaceId)/ProjectGroups/all`""
    Write-Warning "Check your parameters (Octopus API key, URL, SpaceId, etc.), ensure your API key has sufficient permissions, and the Octopus Server is accessible from this machine."
    break
}

# Try to GET the LifecycleId for $LifecycleName
Try {
	$Lifecycle = (Invoke-RestMethod -Method GET "$($OctopusURL)/api/$($SpaceId)/Lifecycles/all" -Headers $Header) | Where-Object {$_.Name -eq $LifecycleName}
    If (!$Lifecycle) {throw}
}
Catch {
    Write-Warning "Unable to find a LifecycleId for the Lifecycle Name `"$($LifecycleName)`" via `"$($OctopusURL)/api/$($SpaceId)/Lifecycles/all`""
    Write-Warning "Check your parameters (Octopus API key, URL, SpaceId, etc.), ensure your API key has sufficient permissions, and the Octopus Server is accessible from this machine."
    break
}

# Create Json payload for new Project creation
$JsonPayload = @{
    Name = $ProjectName
    Description = $ProjectDescription
    ProjectGroupId = $ProjectGroup.Id
    LifecycleId = $Lifecycle.Id
}

# Create Project using $JsonPayload
Try {
    $CheckProjName = (Invoke-RestMethod -Method GET -Uri "$($OctopusURL)/api/$($SpaceId)/projects/all"  -Headers $Header) | Where-Object {$_.Name -eq $ProjectName}
    If ($CheckProjName) {throw}
    Else {
        $NewProject = Invoke-RestMethod -Method POST -Uri "$($OctopusURL)/api/$($SpaceId)/projects" -Body ($JsonPayload | ConvertTo-Json -Depth 10) -Headers $Header
        Write-Host "You may view your new Project at: $($OctopusURL)$($NewProject.Links.Self)"
    }
}
Catch {
    Write-Warning "A Project with the name `"$($ProjectName)`" already exists in `"$($SpaceId)`". Please choose a Project Name that does not exist in this Space."
}
