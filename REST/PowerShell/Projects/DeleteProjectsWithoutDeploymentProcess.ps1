[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true,Position=1)]
    [string]$OctopusUrl = "http://localhost:80",

    [Parameter(Mandatory=$true,Position=2)]
    [string]$ApiKey,
    
    [Parameter(Mandatory=$false,Position=3)]
    [switch]$Delete
    
)

Write-Host "Querying against $OctopusUrl with key $ApiKey\r\n"

# Octopus GET
Function Get-FromOctopus([string]$relUrl) {
  $uri = "$OctopusUrl$relUrl`?apiKey=$ApiKey"
  try {
    return Invoke-RestMethod -Uri $uri -Method Get
  }
  catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 404) {
      return $null
    } else {
      throw $_.Exception
    }
  }
}

# Octopus POST
Function Post-ToOctopus([string]$relUrl, $postObject) {
  $deserialised = $postObject | ConvertTo-Json
  return Invoke-RestMethod -Uri "$OctopusUrl$relUrl`?apiKey=$ApiKey" -Body $deserialised -Method Post
}

# Octopus DELETE
Function Delete-FromOctopus([string]$relUrl) {
  return Invoke-RestMethod -Uri "$OctopusUrl$relUrl`?apiKey=$ApiKey" -Body $deserialised -Method Delete
}

### Put logic here ###
$projects = Get-FromOctopus -relUrl "/api/projects/all"
$projectsToDelete = @()
ForEach ($p in $projects) {
  $name = $p.Name
  $processLink = $p.Links.DeploymentProcess
  $process = Get-FromOctopus -relUrl $processLink
  if ($process -ne $null) {
    Write-Host "Project '$name' has a process template with $($process.Steps.Count) steps"
  } else {
    $projectsToDelete += $p.Id
    Write-Host "Project '$name' appears to be missing a process template and will be deleted" -foregroundcolor "red"
  }
}

if ($Delete) {
  ForEach ($p in $projectsToDelete) {
    Write-Host "Deleting Project '$p'" -foregroundcolor "red"
    Delete-FromOctopus -relUrl "/api/projects/$p"
  }
}