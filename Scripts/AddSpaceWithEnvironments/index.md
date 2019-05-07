# Add Space With Environments

## Description

This script is a starter for bootstrapping a new [Space](https://octopus.com/docs/administration/spaces) in your Octopus instance.

It creates a new space with the provided name, description, and managers. At least one manager team or member must be provided.

Then the script will create the [Environments](https://octopus.com/docs/infrastructure/environments) provided in the newly created space.

## REST PowerShell

```powershell
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$name = "New Space"
$description = "Space for the new, top secret project."
$managersTeams = @() # an array of team Ids to add to Space Managers
$managerTeamMembers = @() # an array of user Ids to add to Space Managers
$environments = @('Development', 'Test', 'Production')

$body = @{
    Name = $name
    Description = $description
    SpaceManagersTeams = $managersTeams
    SpaceManagersTeamMembers = $managerTeamMembers
    IsDefault = $false
    TaskQueueStopped = $false
} | ConvertTo-Json

$response = try {
    Write-Host "Creating space '$name'"
    (Invoke-WebRequest $octopusURL/api/spaces -Headers $header -Method Post -Body $body -ErrorVariable octoError)
} catch [System.Net.WebException] {
    $_.Exception.Response
}

if ($octoError) {
    Write-Host "An error was encountered trying to create the space: $($octoError.Message)"
    exit
}

$space = $response.Content | ConvertFrom-Json

foreach ($environment in $environments) {
    $body = @{
        Name = $environment
    } | ConvertTo-Json

    Write-Host "Creating environment '$environment'"
    $response = try {
        (Invoke-WebRequest "$octopusURL/api/$($space.Id)/environments" -Headers $header -Method Post -Body $body -ErrorVariable octoError)
    } catch [System.Net.WebException] {
        $_.Exception.Response
    }

    if ($octoError) {
        Write-Host "An error was encountered trying to create the environment: $($octoError.Message)"
        exit
    }
}
```

## Octopus.Client PowerShell

```powershell
Add-Type -Path 'path\to\Octopus.Client.dll'

$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"

$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)

$name = "New Space"
$description = "Space for the new, top secret project."
$managersTeams = @() # an array of team Ids to add to Space Managers
$managerTeamMembers = @() # an array of user Ids to add to Space Managers
$environments = @('Development', 'Test', 'Production')


$space = New-Object Octopus.Client.Model.SpaceResource -Property @{
    Name = $name
    Description = $description
    SpaceManagersTeams = New-Object Octopus.Client.Model.ReferenceCollection($managersTeams)
    SpaceManagersTeamMembers = New-Object Octopus.Client.Model.ReferenceCollection($managerTeamMembers)
    IsDefault = $false
    TaskQueueStopped = $false
};

try {
    $space = $repository.Spaces.Create($space)
}
catch {
    Write-Host $_.Exception.Message
    exit
}

$repositoryForSpace = [Octopus.Client.OctopusRepositoryExtensions]::ForSpace($repository, $space)

foreach ($environmentName in $environments) {
    $environment = New-Object Octopus.Client.Model.EnvironmentResource -Property @{
        Name = $environmentName
    }

    try {
        $repositoryForSpace.Environments.Create($environment)
    }
    catch {
        Write-Host $_.Exception.Message
        exit
    }
}
```

## Octopus.Client C#

```csharp
#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

var octopusURL = "https://youroctourl";
var octopusAPIKey = "API-YOURAPIKEY";

var endpoint = new OctopusServerEndpoint(octopusURL, octopusAPIKey);
var repository = new OctopusRepository(endpoint);

var name = "New Space";
var description = "Space for the new, top secret project.";
var managersTeams = new string[] { };
var managersTeamMembers = new string[] { };

var environments = new string[] { "Development", "Test", "Production" };

var space = new SpaceResource
{
    Name = name,
    Description = description,
    SpaceManagersTeams = new ReferenceCollection(managersTeams),
    SpaceManagersTeamMembers = new ReferenceCollection(managersTeamMembers),
    IsDefault = false,
    TaskQueueStopped = false
};

try
{
    Console.WriteLine($"Creating space '{name}'.");
    space = repository.Spaces.Create(space);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}

var repositoryForSpace = repository.ForSpace(space);

foreach(var environmentName in environments)
{
    var environment = new EnvironmentResource {
        Name = environmentName
    };

    try
    {
        Console.WriteLine($"Creating environment '{environmentName}'.");
        repositoryForSpace.Environments.Create(environment);
    }
    catch (Exception ex)
    {
        Console.WriteLine(ex.Message);
        return;
    }
}
```
