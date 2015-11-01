[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true,Position=1)]
    [string]$OctopusUrl = "http://localhost:80",

    [Parameter(Mandatory=$true,Position=2)]
    [string]$ApiKey,
    
    [Parameter(Mandatory=$false,Position=3)]
    [switch]$Delete
    
)

Add-Type -Path "Octopus.Client.dll"

$endpoint = new-object Octopus.Client.OctopusServerEndpoint "$($OctopusURL)","$($APIKey)"    
$repository = new-object Octopus.Client.OctopusRepository $endpoint            

### Put logic here ###

$projects = $repository.Projects.Findall()
$projectsToDelete = @()
ForEach ($p in $projects) {
  $name = $p.Name  
  if (![string]::IsNullOrEmpty($p.DeploymentProcessId)) {
    $process = $repository.DeploymentProcesses.Get($p.links.deploymentprocess)
    Write-Host "Project '$name' has a process template with $($process.Steps.Count) steps"
  } else {
    $projectsToDelete += $p
    Write-Host "Project '$name' appears to be missing a process template and will be deleted" -foregroundcolor "red"
  }
}

if ($Delete) {
  ForEach ($p in $projectsToDelete) {
    Write-Host "Deleting Project $($p.name)" -foregroundcolor "red"
    $repository.Projects.delete($p)
  }
}