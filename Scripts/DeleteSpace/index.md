# Delete Space

## Description

This script deletes a [Space](https://octopus.com/docs/administration/spaces) from your Octopus instance.

**Be very careful when deleting a Space. This operation is destructive and cannot be undone.**

## REST PowerShell

```powershell
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$name = "New Space"

try {
    Write-Host "Getting space '$name'"
    $spaces = (Invoke-WebRequest $octopusURL/api/spaces?take=21000 -Headers $header -Method Get -ErrorVariable octoError).Content | ConvertFrom-Json

    $space = $spaces.Items | Where-Object Name -eq $name

    if ($null -eq $space) {
        Write-Host "Could not find space with name '$name'"
        exit
    }

    $space.TaskQueueStopped = $true
    $body = $space | ConvertTo-Json

    Write-Host "Stopping space task queue"
    (Invoke-WebRequest $octopusURL/$($space.Links.Self) -Headers $header -Method PUT -Body $body -ErrorVariable octoError) | Out-Null

    Write-Host "Deleting space"
    (Invoke-WebRequest $octopusURL/$($space.Links.Self) -Headers $header -Method DELETE -ErrorVariable octoError) | Out-Null

    Write-Host "Action Complete"
}
catch {
    Write-Host "There was an error during the request: $($octoError.Message)"
    exit
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

$space = $repository.Spaces.FindByName($name)

if ($null -eq $space) {
    Write-Host "The space $name does not exist."
    exit
}

try {
    $space.TaskQueueStopped = $true

    $repository.Spaces.Modify($space) | Out-Null
    $repository.Spaces.Delete($space) | Out-Null
} catch {
    Write-Host $_.Exception.Message
}
```

## Octopus.Client C#

```csharp
#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

var OctopusURL = "https://youroctourl";
var OctopusAPIKey = "API-YOURAPIKEY";

var endpoint = new OctopusServerEndpoint(OctopusURL, OctopusAPIKey);
var repository = new OctopusRepository(endpoint);

var name = "New Space";

try
{
    Console.WriteLine($"Getting space '{name}'.");
    var space = repository.Spaces.FindByName(name);

    if (space == null)
    {
        Console.WriteLine($"Could not find space '{name}'.");
        return;
    }

    Console.WriteLine("Stopping task queue.");
    space.TaskQueueStopped = true;

    repository.Spaces.Modify(space);

    Console.WriteLine("Deleting space");
    repository.Spaces.Delete(space);
}
catch (Exception ex)
{
    Console.WriteLine(ex.Message);
    return;
}
```
