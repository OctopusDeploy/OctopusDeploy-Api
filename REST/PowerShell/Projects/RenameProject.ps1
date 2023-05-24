# ==================================================================================================================
# This script renames a Project (and optionally a Project's slug) on the specified Octopus Server.
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
	$NewProjectName = "My New Project Name"
	$ChangeProjectSlug = $true
}

If (!$BypassPrompts) {
	
	# === Prompted Parameters ===
	$OctopusAPIKey = (Read-Host "Enter your Octopus API key (example: `"API-XXXXXXXXXXXXXXXXXX`")").trim('"')
	$OctopusURL = (Read-Host "Enter your Octopus Instance URL with no trailing slash (i.e. `"http://YOUR_OCTOPUS_URL.bla`")").trim('"')
	$SpaceId = (Read-Host "Enter the SpaceId where the Library Variable Set resides (example: `"Spaces-1`")").trim('"')
	$ProjectName = (Read-Host "Enter the current Project name (example: `"My Project`")").trim('"')
    $NewProjectName = (Read-Host "Enter the new Project name (example: `"My New Project Name`")").trim('"')
    $ChangeProjectSlugPrompt = (Read-Host "Would you like to change the Project's Slug to match the new Project Name? (Type `"Y`" for yes or `"N`" for no)").trim('"')
	While (($ChangeProjectSlugPrompt -ne "Y") -and ($ChangeProjectSlugPrompt -ne "N")) {
		$ChangeProjectSlugPrompt = (Read-Host "Would you like to change the Project's Slug to match the new Project Name? (Type Y for yes or N for no)").trim('"')
	}
	If ($ChangeProjectSlugPrompt -eq "Y") {$ChangeProjectSlug = $true}
	If ($ChangeProjectSlugPrompt -eq "N") {$ChangeProjectSlug = $false}
}

$Header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }

# Special character check
$CheckSpecialChar = $NewProjectName | Select-String '[^ !@#$%^&();`~,.+=\-\w]' -AllMatches | ForEach-Object { $_.Matches.Value }
If ($CheckSpecialChar) {
    $PrintSpecialChars = $CheckSpecialChar -join ' '
    Write-Warning "The following special characters were detected and may cause this action to fail:"
    Write-Host "$($PrintSpecialChars)"
    If (!$BypassPrompts) {
        Write-Host ""
        $Confirm = (Read-Host "Type `"Y`" to continue as is, `"R`" to remove these characters and continue or `"N`" to quit)").trim('"')
	    While (($Confirm -ne "N") -and ($Confirm -ne "Y")  -and ($Confirm -ne "R")) {
		    $Confirm = (Read-Host "Type `"Y`" to continue as is, `"R`" to remove these characters and continue or `"N`" to quit)").trim('"')
	    }  
	    If ($Confirm -eq "N") {
		    Write-Warning "Aborted. No changes were made."
		    break
	    }
	    If ($Confirm -eq "R") {
		    Write-Host "Requested new Project name: $($NewProjectName)"
            $NewProjectName = $NewProjectName -replace '[^ !@#$%^&();`~,.+=\-\w]',''
            Write-Host ">Adjusted new Project name: $($NewProjectName)"
	    }
    }      
}

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

# Confirm no Projects already exist in $SpaceId with $NewProjectName
$ProjectNameCheck = (Invoke-RestMethod -Method GET "$($OctopusURL)/api/$($SpaceId)/Projects/all" -Headers $Header) | Where-Object {$_.Name -eq $NewProjectName}
If ($ProjectNameCheck) {
	Write-Warning "A Project named `"$($NewProjectName)`" ($($ProjectNameCheck.Id)) already exists. Please try a different new Project name."
	break
}

# Set new Project name (and slug via $ChangeProjectSlug)
$Project.Name = $NewProjectName
If ($ChangeProjectSlug) {
	$SlugConvert = $NewProjectName.ToLower().Replace('_','-') -replace '\s','-'
    $SlugArray = $SlugConvert | Select-String '(\w+)' -AllMatches | ForEach-Object { $_.Matches.Value }
    $Slug = $SlugArray -join '-'
    $Project.Slug = $Slug
}

# Save Project changes
$SaveProject = Invoke-RestMethod -Method PUT "$($OctopusURL)/api/$($SpaceId)/Projects/$($Project.Id)" -Headers $header -Body ($Project | ConvertTo-Json -Depth 10)

$ProjectCheck = Invoke-RestMethod -Method GET -Uri "$($OctopusURL)/api/$($SpaceId)/Projects/$($Project.Id)" -Headers $Header
If ($ProjectCheck.Name -eq $NewProjectName) {
	Write-Host "Project `"$ProjectName`" ($($Project.Id)) is now named `"$NewProjectName`" with the slug `"$($ProjectCheck.Slug)`""
}
