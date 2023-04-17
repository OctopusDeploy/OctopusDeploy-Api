$ErrorActionPreference = "Stop";

# Octopus URL
$OctopusURL = "https://your.octopus.app"
$OctopusAPIKey = "API-KEY"
$Header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }

# Working variables
$SpaceName = "Your-Space-Name"

# Provide the username/org for the Git repo
$username = "your-git-user-or-org-name"
# Provide the name of the Git Credential in the Octopus Library to use.
$credentialName = "Your-Git-Credentials"
# Provide the name of the Repo to place all files in.
$repo = "repo-name"
# Set default branch to use for conversion
$defaultBranch = "main"
# Set to $True to continue conversion if a project fails to convert due to an error
$continueOnConversionError = $False

# Set to $False to actually perform updates
$WhatIf = $False

# Optional,  Project names. Use this list to limit the projects that are worked on
#$ProjectNames = @("Project 1", "Project 2", "Project Y")
$ProjectNames = @()
#$ProjectExclusionList = @("Project X")
$ProjectExclusionList = @()

# Git url
#$gitUrl = "https://$($username)@bitbucket.org/$($username)/$($repo.ToLowerInvariant()).git" # BitBucket example HTTPS url
$gitUrl = "https://github.com/$username/$repo"

Write-Host "WhatIf is set to: $WhatIf" -ForegroundColor Blue

# Get space
$Spaces = Invoke-RestMethod -Uri "$OctopusURL/api/spaces?partialName=$([uri]::EscapeDataString($SpaceName))&skip=0&take=100" -Headers $Header 
$Space = $Spaces.Items | Where-Object { $_.Name -eq $SpaceName }
$spaceId = $Space.Id
if ($null -eq $SpaceName) {
    throw "Couldn't find space '$SpaceName' in Octopus instance: $OctopusURL"
}

# Get Library Git Credential
$credentials = @()
$response = $null
do {
    $uri = if ($response) { $OctopusURL + $response.Links.'Page.Next' } else { "$OctopusURL/api/$($spaceId)/git-credentials" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $Header
    $credentials += $response.Items
} while ($response.Links.'Page.Next')

$credential = $credentials | Where-Object { $_.Name -eq $credentialName }

if ($null -eq $credential) {
    throw "Couldn't find Git credentials '$credentialName' in Octopus instance: $OctopusURL"
}

# Get projects
Write-Output "Retrieving projects from $($OctopusURL)"
$projects = @()
$response = $null
do {
    $uri = if ($response) { $OctopusURL + $response.Links.'Page.Next' } else { "$OctopusURL/api/$($SpaceId)/projects" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $Header
    $projects += $response.Items
} while ($response.Links.'Page.Next')

if ($ProjectNames.Length -gt 0) {    
    Write-Output "Filtering list of projects to work on."
    $projects = ($projects | Where-Object { $ProjectNames -icontains $_.Name })
}
else {
   
    $ContinueResult = Read-Host "Working on ALL projects to convert to GIT. Please type y/yes to confirm."

    if ($ContinueResult -ieq "y" -or $ContinueResult -ieq "yes") {
        Write-Host "User confirmed to continue working on ALL projects..." -ForegroundColor Yellow
    }
    else {
        Write-Warning "User aborted conversion process."
        Exit 0
    }
}

if ($ProjectExclusionList.Length -gt 0) {
    Write-Output "Excluding $($ProjectExclusionList.Length) project(s) from the conversion process"
    Write-Warning "Projects excluded: $(@($ProjectExclusionList | ForEach-Object { "$_" }) -Join ",")"
    $projects = $projects | Where-Object { $ProjectExclusionList -inotcontains $_.Name }
}

# Check we have projects to work on
if ($projects.Length -eq 0) {
    Write-Warning "No projects to work on, exiting"
    Exit 0
}

Write-Output "Number of projects to work on: $($projects.Length)"
foreach ($project in $projects) {
    if ($project.IsVersionControlled -eq $True) {
        Write-Warning "Project '$($project.Name)' is already configured for version control, skipping."
        continue;
    }
    else {
        $projectName = $project.Name
        $projectSlug = $projectName.ToLowerInvariant().Replace(" ", "-")
        $projectId = $project.Id
        if ($WhatIf -eq $True) {
            Write-Host "WHATIF: Would've converted project tenant '$($projectName)' to use version control." -ForegroundColor Yellow
        }
        else {
            Write-Output "Updating project '$($projectName)' to use version control"
            $body = @{
                CommitMessage          = "Initial commit of deployment process for $projectName"
                VersionControlSettings = @{
                    BasePath        = ".octopus/$projectSlug"
                    ConversionState = @{
                        VariablesAreInGit = $false
                    }
                    Credentials     = @{
                        Id   = $credential.Id
                        Type = "Reference"
                    }
                    DefaultBranch   = $defaultBranch
                    Type            = "VersionControlled"
                    Url             = $gitUrl
                }
            } | ConvertTo-Json
            
            try {
                Write-Output "Making request to $OctopusURL/api/$spaceId/projects/$projectId/git/convert"
                Invoke-RestMethod -Uri "$OctopusURL/api/$spaceId/projects/$projectId/git/convert" -Headers $Header -Method Post -Body $body | Out-Null
            }
            catch {
                Write-Warning "Error caught converting project '$projectName' to version control: $($_.Exception.Message)"
                if ($continueOnConversionError -eq $False) {
                    throw
                }
            }
        }
    }
}
