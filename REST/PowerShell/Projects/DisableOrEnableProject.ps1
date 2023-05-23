# ==================================================================================================================
# This script disables or enables a Project on the specified Octopus Server.
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
    $ProjectEnabled = $false
}

If (!$BypassPrompts) {
	
	# === Prompted Parameters ===
	$OctopusAPIKey = (Read-Host "Enter your Octopus API key (example: `"API-XXXXXXXXXXXXXXXXXX`")").trim('"')
	$OctopusURL = (Read-Host "Enter your Octopus Instance URL with no trailing slash (i.e. `"http://YOUR_OCTOPUS_URL.bla`")").trim('"')
	$SpaceId = (Read-Host "Enter the SpaceId where the Library Variable Set resides (example: `"Spaces-1`")").trim('"')
	$ProjectName = (Read-Host "Enter a name for your new Project (example: `"My Project`")").trim('"')
	$ProjectStatusPrompt = (Read-Host "Type `"D`" to Disable or `"E`" to Enable `"$($ProjectName)`"").trim('"')
	While (($ProjectStatusPrompt -ne "D") -and ($ProjectStatusPrompt -ne "E")) {
		$ProjectStatusPrompt = (Read-Host "Type `"D`" to Disable or `"E`" to Enable `"$($ProjectName)`"").trim('"')
	}
	If ($ProjectStatusPrompt -eq "D") {$ProjectEnabled = $false}
	If ($ProjectStatusPrompt -eq "E") {$ProjectEnabled = $true}
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

# Check if Project is already Disabled/Enabled
If ($Project.IsDisabled -eq !$ProjectEnabled) {
    If ($Project.IsDisabled) {
        Write-Host "`"$($ProjectName)`" ($($Project.Id)) already disabled! No action required!"
        break
    }
    If (!$Project.IsDisabled) {
        Write-Host "`"$($ProjectName)`" ($($Project.Id)) already enabled! No action required!"
        break
    }
}

# Disable/Enable Project
$Project.IsDisabled = !$ProjectEnabled
If ($ProjectEnabled -eq $false) {
	Write-Host "Disabling `"$($ProjectName)`" ($($Project.Id))"
}
If ($ProjectEnabled -eq $true) {
	Write-Host "Enabling `"$($ProjectName)`" ($($Project.Id))"
}
# Save Project changes
Try {
    $SaveProject = Invoke-RestMethod -Method PUT -Uri "$($OctopusURL)/api/$($SpaceId)/Projects/$($Project.Id)" -Headers $Header -Body ($Project | ConvertTo-Json -Depth 10)
}
Catch {
    Write-Warning "Something went wrong when attempting a PUT via `"$($OctopusURL)/api/$($SpaceId)/Projects/$($Project.Id)`"."
}

$ProjectCheck = Invoke-RestMethod -Method GET -Uri "$($OctopusURL)/api/$($SpaceId)/Projects/$($Project.Id)" -Headers $Header
If ($ProjectCheck.IsDisabled -eq !$ProjectEnabled) {
	Write-Host "Success!"
}
