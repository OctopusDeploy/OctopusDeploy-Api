$ErrorActionPreference = "Stop";

if ($PSEdition -eq "Core") {
    $PSStyle.OutputRendering = "PlainText"
}

$stopwatch = [system.diagnostics.stopwatch]::StartNew()

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "Default"

# Define the file path
$filePath = "/path/to/output.xml"

# Helper functions
function Get-Name {
    param (
        [string]$Id,
        [array]$list
    )

    if ([string]::IsNullOrWhiteSpace($Id)) {
        return $null
    }
    else {
        $item = $list | Where-Object { $_.Id -ieq $Id }
        if ($null -ne $item) {
            return $item.Name
        }
        else {
            return $null
        }
    }
}

# Get space
Write-Output "Retrieving space '$($spaceName)'"
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -ieq $spaceName }

# Get all project groups
Write-Output "Retrieving all project groups"
$projectGroups = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/projectgroups" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $projectGroups += $response.Items
} while ($response.Links.'Page.Next')

# Get all projects
Write-Output "Retrieving all projects"
$projects = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/projects" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $projects += $response.Items
} while ($response.Links.'Page.Next')

# Get all environments
Write-Output "Retrieving all environments"
$environments = @()
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/environments" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    $environments += $response.Items
} while ($response.Links.'Page.Next')

Write-Output "Dumping all deployments"

# Create a FileStream and XmlWriterSettings
$fileStream = [System.IO.FileStream]::new($filePath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
$xmlWriterSettings = [System.Xml.XmlWriterSettings]::new()
$xmlWriterSettings.Indent = $true

# Create the XmlWriter
$xml = [System.Xml.XmlWriter]::Create([System.IO.StreamWriter]::new($fileStream), $xmlWriterSettings)
$xml.WriteStartElement("Deployments")

# Initialize a HashSet to track seen deployments and releases
$deploymentsSeenBefore = [System.Collections.Generic.HashSet[string]]::new()
$releasesSeenBefore = @{}
$response = $null
do {
    $uri = if ($response) { $octopusURL + $response.Links.'Page.Next' } else { "$octopusURL/api/$($space.Id)/deployments" }
    $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $header
    
    foreach ($deployment in $response.Items) {
        if ($deploymentsSeenBefore.Contains($deployment.Id)) {
            continue
        }
        # Get the release for this deployment
        [PsCustomObject]$release = $null
        if ($releasesSeenBefore.ContainsKey($deployment.ReleaseId)) {
            $release = $releasesSeenBefore[$deployment.ReleaseId]
        }
        else {
            $release = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/releases/$($deployment.ReleaseId)" -Headers $header
            $releasesSeenBefore.Add($deployment.ReleaseId, $release) | Out-Null
        }
       
        $deploymentsSeenBefore.Add($deployment.Id) | Out-Null

        $xml.WriteStartElement("Deployment")
        $xml.WriteElementString("Environment", (Get-Name $deployment.EnvironmentId $environments))
        $xml.WriteElementString("Project", (Get-Name $deployment.ProjectId $projects))
        $xml.WriteElementString("ProjectGroup", (Get-Name $deployment.ProjectGroupId $projectGroups))
        $xml.WriteElementString("Created", $deployment.Created.ToString("s"))
        $xml.WriteElementString("Name", $deployment.Name)
        $xml.WriteElementString("Id", $deployment.Id)
        $xml.WriteElementString("ReleaseNotes", $release.ReleaseNotes)
        $xml.WriteEndElement()
    }

    Write-Output ("Wrote {0:n0} of {1:n0} deployments..." -f $deploymentsSeenBefore.Count, $response.TotalResults)

} while ($response.Links.'Page.Next')

# End the XML document and flush the writer
$xml.WriteEndElement()
$xml.Flush()
$xml.Close()
$fileStream.Close()

$stopwatch.Stop()
Write-Output "Completed execution in $($stopwatch.Elapsed)"