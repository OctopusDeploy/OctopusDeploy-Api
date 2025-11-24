# =======================================================================
# This script can list, output and/or delete Projects that are
# currently without a Deployment Process on the specified Octopus Server.
# =======================================================================

$ErrorActionPreference = "Stop";

# ====== BYPASS PROMPTS? ======
$BypassPrompts = $false # Set to $true if you wish to predefine your parameters


# ====== PARAMETERS ======
If ($BypassPrompts) {
	
	# === Predefined Parameters (Optional) ===
	$OctopusURL = "http://YOUR_OCTOPUS_URL.bla"
    $OctopusAPIKey = "API-XXXXXXXXXXXXXXXXXX"
	$SpaceId = "All" # SpaceId or use "All" to check all Spaces
    $DirPath = "C:\New Folder" # Directory path for option (6) below (e.g. "C:\New Folder")
    $FinalOption = 1 # Choose a number from the list below (1-6)
    # (1) Do nothing (quit)
    # (2) Delete all Projects with no Deployment Process (regardless of whether they have Runbooks or Releases with Deployments)
    # (3) Delete all Projects with no Deployment Process, ignore any Projects with Runbooks
    # (4) Delete all Projects with no Deployment Process, ignore any Projects that contain Releases with Deployments
    # (5) Delete all Projects with no Deployment Process, ignore any Projects with Runbooks or that contain Releases with Deployments
    # (6) Create a text file containing the list of Projects
}

If (!$BypassPrompts) {
	
	# === Prompted Parameters ===
	$OctopusAPIKey = (Read-Host "Enter your Octopus API key (example: `"API-XXXXXXXXXXXXXXXXXX`")").trim('"')
	$OctopusURL = (Read-Host "Enter your Octopus Instance URL with no trailing slash (i.e. `"http://YOUR_OCTOPUS_URL.bla`")").trim('"')
	$SpaceId = (Read-Host "Enter the SpaceId where you would like to check for Projects without a Deployment Process (example: `"Spaces-1`" or use `"All`" to check all Spaces)").trim('"')
}

$Header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }

# ====== SCRIPT BODY ======
# Set arrays for later
$EmptyProjects = @()
$EmptyProjectsWithRunbooks = @()
$EmptyProjectsWithDeployments = @()
$EmptyProjectsWithNeither = @()
$EmptyProjectsWithBoth = @()

# Find Projects without a Deployment Process in All Spaces
If ($SpaceId -eq "All") {
    $Spaces = Invoke-RestMethod -Method GET "$($OctopusURL)/api/Spaces/all" -Headers $Header
    Foreach ($Space in $Spaces) {
        $SpaceId = $Space.Id
        Write-Host "Processing $($Space.name) ($($SpaceId))"
        Try {
            $SkipSpace = $false
            $Projects = (Invoke-RestMethod -Method GET "$($OctopusURL)/api/$($SpaceId)/Projects/all" -Headers $Header)
        }
        Catch {
            $SkipSpace = $true
            Write-Warning "This User does not have permissions in $($Space.name) ($($SpaceId)). Continuing..."
        }
        If ($SkipSpace -eq $false) {
            Foreach ($Project in $Projects) {
                $GitRefDPCounter = 0
                Write-Host "Processing $($Project.name) ($($Project.Id))"
                If ($Project.PersistenceSettings.Type -eq "Database") {
                    $DeploymentProcess = Invoke-RestMethod -Method GET "$($OctopusURL)$($Project.Links.DeploymentProcess)" -Headers $Header
                }
                If (($Project.PersistenceSettings.Type -eq "VersionControlled") -and ($GitRefDPCounter -eq 0)) {
                    Try {
                    $GitRefList = Invoke-RestMethod -Method GET "$($OctopusURL)/api/Spaces-1/projects/$($Project.Id)/git/branches" -Headers $Header
                    }
                    Catch {
                        Write-Warning "$($Project.Name) ($($Project.Id)) does not have valid version control credentials. Continuing..."
                    }
                    $GitRefs = $GitRefList.Items
                    Foreach ($GitRef in $GitRefs) {
                        $GitRefDPLink = $GitRef.Links.DeploymentProcess
                        Try {
                            $DeploymentProcess = Invoke-RestMethod -Method GET "$($OctopusURL)$($GitRefDPLink)" -Headers $Header
                        }
                        Catch {
                            Write-Warning "$($GitRef.Name) is not initialized for $($Project.Name) ($($Project.Id)). Continuing..."
                        }
                        If (($DeploymentProcess.Steps) -or ($DeploymentProcess.Steps.Count -gt 0)) {
                            $GitRefDPCounter ++
                        }
                    }
                }
                If ((!$DeploymentProcess.Steps) -or ($DeploymentProcess.Steps.Count -eq 0) -and ($GitRefDPCounter -eq 0)) {
                    $EmptyProjects += $Project
                }
            }
        }
    }
}
# Find Projects without a Deployment Process in $SpaceId
Else {
    Try {
        $SkipSpace = $false
        $Space = (Invoke-RestMethod -Method GET "$($OctopusURL)/api/$($SpaceId)" -Headers $Header)
        $Projects = (Invoke-RestMethod -Method GET "$($OctopusURL)/api/$($SpaceId)/Projects/all" -Headers $Header)
    }
    Catch {
        $SkipSpace = $true
        Write-Warning "This User does not have permissions in $($Space.name) ($($SpaceId)). Continuing..."
    }
    If ($SkipSpace -eq $false) {
        Foreach ($Project in $Projects) {
            $GitRefDPCounter = 0
            Write-Host "Processing $($Project.name) ($($Project.Id))"
			# Check for a Deployment Process in a normal Project
            If ($Project.PersistenceSettings.Type -eq "Database") {
                $DeploymentProcess = Invoke-RestMethod -Method GET "$($OctopusURL)$($Project.Links.DeploymentProcess)" -Headers $Header
            }
			# Check for a Deployment Process in a Git-enabled Project
            If (($Project.PersistenceSettings.Type -eq "VersionControlled") -and ($GitRefDPCounter -eq 0)) {
                Try {
                $GitRefList = Invoke-RestMethod -Method GET "$($OctopusURL)/api/Spaces-1/projects/$($Project.Id)/git/branches" -Headers $Header
                }
                Catch {
                    Write-Warning "$($Project.Name) ($($Project.Id)) does not have valid version control credentials. Continuing..."
                }
                $GitRefs = $GitRefList.Items
                Foreach ($GitRef in $GitRefs) {
                    $GitRefDPLink = $GitRef.Links.DeploymentProcess
                    Try {
                        $DeploymentProcess = Invoke-RestMethod -Method GET "$($OctopusURL)$($GitRefDPLink)" -Headers $Header
                    }
                    Catch {
                        Write-Warning "$($GitRef.Name) is not initialized for $($Project.Name) ($($Project.Id)). Continuing..."
                    }
                    If (($DeploymentProcess.Steps) -or ($DeploymentProcess.Steps.Count -gt 0)) {
                        $GitRefDPCounter ++
                    }
                }
            }
            If ((!$DeploymentProcess.Steps) -or ($DeploymentProcess.Steps.Count -eq 0) -and ($GitRefDPCounter -eq 0)) {
                $EmptyProjects += $Project
            }
        }
    }
}

# Check $EmptyProjects for Runbooks and Releases with Deployments
Foreach ($EmptyProject in $EmptyProjects) {
    $Runbooks = Invoke-RestMethod -Method GET "$($OctopusURL)/api/$($EmptyProject.SpaceId)/Projects/$($EmptyProject.Id)/Runbooks" -Headers $Header
    If ($Runbooks.Items) {
    $EmptyProjectsWithRunbooks += $EmptyProject
    }
    $Releases = Invoke-RestMethod -Method GET "$($OctopusURL)/api/$($EmptyProject.SpaceId)/Projects/$($EmptyProject.Id)/Releases" -Headers $Header
    If ($Releases.Items) {
        $ProjectReleases = $Releases.Items
        Foreach ($ProjectRelease in $ProjectReleases) {
            Write-Host "Checking $($ProjectRelease.Id) for $($EmptyProject.Name) ($($EmptyProject.Id))"
            $DeploymentCounter = 0
            If ($DeploymentCounter -lt 1) {
                $Deployments = Invoke-RestMethod -Method GET "$($OctopusURL)/api/$($EmptyProject.SpaceId)/Releases/$($ProjectRelease.Id)/Deployments" -Headers $Header
                If (!$Deployments) {
                    $DeploymentCounter ++
                }
            }
        }
    $EmptyProjectsWithDeployments += $EmptyProject
    }

    If (($EmptyProjectsWithRunbooks.Id -contains $EmptyProject.Id) -and ($EmptyProjectsWithDeployments.Id -contains $EmptyProject.Id)) {
        $EmptyProjectsWithBoth += $EmptyProject
        $EmptyProjectsWithDeployments = $EmptyProjectsWithDeployments -ne $EmptyProject
        $EmptyProjectsWithRunbooks = $EmptyProjectsWithRunbooks -ne $EmptyProject
    }
    If (($EmptyProjectsWithRunbooks.Id -notcontains $EmptyProject.Id) -and ($EmptyProjectsWithDeployments.Id -notcontains $EmptyProject.Id)) {
        $EmptyProjectsWithNeither += $EmptyProject
    }
}
Write-Host ""
Write-Host "==="
Write-Host "Projects with no Deployment Process, Runbooks, or Deployments:"
Write-Host "--------------------------------------------------------------"
Foreach ($_ in $EmptyProjectsWithNeither) {
    Write-Host ">$($_.Name) ($($_.Id))"
    Write-Host ">$($OctopusURL)$($_.Links.Web)"
    Write-Host ""
}
Write-Host ""
Write-Host "==="
Write-Host "Projects with no Deployment Process, but contains Runbooks"
Write-Host "----------------------------------------------------------"
Foreach ($_ in $EmptyProjectsWithRunbooks) {
    Write-Host ">$($_.Name) ($($_.Id))"
    Write-Host ">$($OctopusURL)$($_.Links.Web)"
    Write-Host ""
}
Write-Host ""
Write-Host "==="
Write-Host "Projects with no Deployment Process, but contains Releases with Deployments"
Write-Host "---------------------------------------------------------------------------"
Foreach ($_ in $EmptyProjectsWithDeployments) {
    Write-Host ">$($_.Name) ($($_.Id))"
    Write-Host ">$($OctopusURL)$($_.Links.Web)"
    Write-Host ""
}
Write-Host ""
Write-Host "==="
Write-Host "Projects with no Deployment Process, but contains both Runbooks and Deployments:"
Write-Host "--------------------------------------------------------------------------------"
Foreach ($_ in $EmptyProjectsWithBoth) {
    Write-Host ">$($_.Name) ($($_.Id))"
    Write-Host ">$($OctopusURL)$($_.Links.Web)"
    Write-Host ""
}

If (!$BypassPrompts) {
    Write-Host "Please select one of the following options:"
    Write-Host "-------------------------------------------"
    Write-Host "(1) Do nothing (quit)"
    Write-Host "(2) Delete all Projects with no Deployment Process (regardless of whether they have Runbooks or Releases with Deployments)"
    Write-Host "(3) Delete all Projects with no Deployment Process, ignore any Projects with Runbooks"
    Write-Host "(4) Delete all Projects with no Deployment Process, ignore any Projects that contain Releases with Deployments"
    Write-Host "(5) Delete all Projects with no Deployment Process, ignore any Projects with Runbooks or that contain Releases with Deployments"
    Write-Host "(6) Create a text file containing the list of Projects"
    $FinalOption = (Read-Host "Choose a number from the list above (1-6)")
    While ($FinalOption -notin 1..6) {
        $FinalOption = (Read-Host "Choose a number from the list above (1-6)")
    }
}
$ProjectsToDelete = @()
If ($FinalOption -eq 1) {
    Write-Host "No changes have been made. Quitting..."
    break
}
If ($FinalOption -eq 2) {
    Write-Host "Deleting all Projects with no Deployment Process (regardless of whether they have Runbooks or Releases with Deployments)"
    Foreach ($EmptyProject in $EmptyProjects) {
        Write-Host "Deleting Project "$($EmptyProject.Name)" ($($EmptyProject.Id)) in $($EmptyProject.SpaceId)"
        Invoke-RestMethod -Method DEL "$($OctopusURL)/api/$($EmptyProject.SpaceId)/Projects/$($EmptyProject.Id)" -Headers $Header
    }
}
If ($FinalOption -eq 3) {
    Write-Host "Deleting all Projects with no Deployment Process, ignoring any Projects with Runbooks"
    Foreach ($_ in $EmptyProjectsWithNeither) { $ProjectsToDelete += $_ }
    Foreach ($_ in $EmptyProjectsWithDeployments) { $ProjectsToDelete += $_ }
    Foreach ($_ in $ProjectsToDelete) {
        Write-Host "Deleting Project "$($_.Name)" ($($_.Id)) in $($_.SpaceId)"
        Invoke-RestMethod -Method DEL "$($OctopusURL)/api/$($_.SpaceId)/Projects/$($_.Id)" -Headers $Header
    }
}
If ($FinalOption -eq 4) {
    Write-Host "Deleting all Projects with no Deployment Process, ignoring any Projects that contain Releases with Deployments"
    Foreach ($_ in $EmptyProjectsWithNeither) { $ProjectsToDelete += $_ }
    Foreach ($_ in $EmptyProjectsWithRunbooks) { $ProjectsToDelete += $_ }
    Foreach ($_ in $ProjectsToDelete) {
        Write-Host "Deleting Project "$($_.Name)" ($($_.Id)) in $($_.SpaceId)"
        Invoke-RestMethod -Method DEL "$($OctopusURL)/api/$($_.SpaceId)/Projects/$($_.Id)" -Headers $Header
    }
}
If ($FinalOption -eq 5) {
    Write-Host "Deleting all Projects with no Deployment Process, ignoring any Projects with Runbooks or that contain Releases with Deployments"
    Foreach ($_ in $EmptyProjectsWithNeither) { $ProjectsToDelete += $_ }
    Foreach ($_ in $ProjectsToDelete) {
        Write-Host "Deleting Project "$($_.Name)" ($($_.Id)) in $($_.SpaceId)"
        Invoke-RestMethod -Method DEL "$($OctopusURL)/api/$($_.SpaceId)/Projects/$($_.Id)" -Headers $Header
    }
}
If ($FinalOption -eq 6) {
    If (!$BypassPrompts) {
        $DirPath = (Read-Host "Please specify a location to output the list of Projects (e.g. `"C:\New Folder`")").trim('"')
    }
    Write-Host "No changes have been made to your Octopus instance. Creating text file..."
    $TimeStamp = $(((get-date).ToUniversalTime()).ToString("yyyyMMddTHHmmssZ"))
    $FileName = "ProjectsWithoutDeploymentProcesses.$($TimeStamp).txt"
    Try {
        New-Item -ItemType "directory" -Path "$($DirPath)"
    }
    Catch {
        $TestPath = Test-Path "$($DirPath)"
        If ($TestPath) {
            Write-Host "Directory already exists. Continuing..."
        }
        If (!$TestPath) {
            Write-Warning "Unable to create or access directory. Please check your local machine permissions to this folder and make sure you typed the location correctly."
            break
        }
    }
    New-Item -Path "$($DirPath)" -Name "$($FileName)" -ItemType "file"
    Function AddToOutput {
        Param ($Text)
        Add-Content -Path "$($DirPath)\$($FileName)" -Value $Text
    }
    AddToOutput -Text "==="
    AddToOutput -Text "Projects with no Deployment Process, Runbooks, or Deployments:"
    AddToOutput -Text "--------------------------------------------------------------"
    Foreach ($_ in $EmptyProjectsWithNeither) {
        AddToOutput -Text ">$($_.Name) ($($_.Id))"
        AddToOutput -Text ">$($OctopusURL)$($_.Links.Web)"
        AddToOutput -Text ""
    }
    AddToOutput -Text ""
    AddToOutput -Text "==="
    AddToOutput -Text "Projects with no Deployment Process, but contains Runbooks"
    AddToOutput -Text "----------------------------------------------------------"
    Foreach ($_ in $EmptyProjectsWithRunbooks) {
        AddToOutput -Text ">$($_.Name) ($($_.Id))"
        AddToOutput -Text ">$($OctopusURL)$($_.Links.Web)"
        AddToOutput -Text ""
    }
    AddToOutput -Text ""
    AddToOutput -Text "==="
    AddToOutput -Text "Projects with no Deployment Process, but contains Releases with Deployments"
    AddToOutput -Text "---------------------------------------------------------------------------"
    Foreach ($_ in $EmptyProjectsWithDeployments) {
        AddToOutput -Text ">$($_.Name) ($($_.Id))"
        AddToOutput -Text ">$($OctopusURL)$($_.Links.Web)"
        AddToOutput -Text ""
    }
    AddToOutput -Text ""
    AddToOutput -Text "==="
    AddToOutput -Text "Projects with no Deployment Process, but contains both Runbooks and Deployments:"
    AddToOutput -Text "--------------------------------------------------------------------------------"
    Foreach ($_ in $EmptyProjectsWithBoth) {
        AddToOutput -Text ">$($_.Name) ($($_.Id))"
        AddToOutput -Text ">$($OctopusURL)$($_.Links.Web)"
        AddToOutput -Text ""
    }
    Write-Host ""
    Write-Host ">>>>>>>>>>>>>>>>>"
    Write-Host "Text file created: $($DirPath)\$($FileName)"
    Write-Host ">>>>>>>>>>>>>>>>>"
}
