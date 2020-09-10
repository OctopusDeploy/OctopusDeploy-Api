# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$librarySetName = "MyLibrarySet"

try
{
    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}
    
    # Get library set reference
    $librarySet = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/libraryvariablesets/all" -Headers $header) | Where-Object {$_.Name -eq $librarySetName}

    # Get all projects
    $projects = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header

    # Loop through projects
    Write-Host "The following projects are using $librarySetName"
    foreach ($project in $projects)
    {
        # Check to see if it's using the set
        if ($project.IncludedLibraryVariableSetIds -contains $librarySet.Id)
        {
            Write-Host "$($project.Name)"
        }
    }
}
catch
{
    Write-Host $_.Exception.Message
}