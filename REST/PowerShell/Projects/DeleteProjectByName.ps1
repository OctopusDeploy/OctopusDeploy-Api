# ==================================================================================================================
# This script deletes a Project on the specified Octopus Server.
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
}

If (!$BypassPrompts) {
	
	# === Prompted Parameters ===
	$OctopusAPIKey = (Read-Host "Enter your Octopus API key (example: `"API-XXXXXXXXXXXXXXXXXX`")").trim('"')
	$OctopusURL = (Read-Host "Enter your Octopus Instance URL with no trailing slash (i.e. `"http://YOUR_OCTOPUS_URL.bla`")").trim('"')
	$SpaceId = (Read-Host "Enter the SpaceId where the Library Variable Set resides (example: `"Spaces-1`")").trim('"')
	$ProjectName = (Read-Host "Enter a name for your new Project (example: `"My Project`")").trim('"')
}

$Header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }

# ====== SCRIPT BODY ======
# Try to GET the ProjectId for $ProjectName
Try {
    $Project = (Invoke-RestMethod -Method GET "$($OctopusURL)/api/$($SpaceId)/Projects/all" -Headers $Header) | Where-Object {$_.Name -eq $ProjectName}
    If (!$Project) {throw}
}
Catch {
    Write-Warning "Unable to find a ProjectId for the Project Name `"$($ProjectName)`" via `"$($OctopusURL)/api/$($SpaceId)/Projects/all`""
    Write-Warning "Check your parameters (Octopus API key, URL, SpaceId, etc.), ensure your API key has sufficient permissions, and the Octopus Server is accessible from this machine."
    break
}

# Confirmation (ignored if $BypassPrompts = $true)
If (!$BypassPrompts) {
    Write-Host "=================================================================================================================================="
    $Confirm = (Read-Host "Are you sure you want to DELETE the Project `"$ProjectName`" ($($Project.Id))? This cannot be undone. (Type Y to continue or N to quit)").trim('"')
	While (($Confirm -ne "N") -and ($Confirm -ne "Y")) {
		$Confirm = (Read-Host "Are you sure you want to DELETE the Project `"$ProjectName`" ($($Project.Id))? This cannot be undone. (Type Y to continue or N to quit)").trim('"')
	}  
	If ($Confirm -eq "N") {
		Write-Warning "Aborted. No changes were made."
		break
	}
}

# Delete Project
Invoke-RestMethod -Method DEL "$($OctopusURL)/api/$($SpaceId)/Projects/$($Project.Id)" -Headers $Header
Try {
    $DeleteCheck = (Invoke-RestMethod -Method GET "$($OctopusURL)/api/$($SpaceId)/Projects/all" -Headers $Header) | Where-Object {$_.Name -eq $ProjectName}
    If (!$DeleteCheck) {
        Write-Host "The Project named `"$($ProjectName)`" ($($Project.Id)) was DELETED."
    }
    If ($DeleteCheck) {throw}
}
Catch {
    Write-Warning "Unable to DELETE the Project `"$($ProjectName)`" via `"$($OctopusURL)/api/$($SpaceId)/Projects/$($Project.Id)`""
    Write-Warning "Check your parameters (Octopus API key, URL, SpaceId, etc.), ensure your API key has sufficient permissions, and the Octopus Server is accessible from this machine."
    break
}
