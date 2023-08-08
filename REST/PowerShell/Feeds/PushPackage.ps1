$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }
$spaceName = "default"
$packageFile = "path\to\package"
$timeout = New-Object System.TimeSpan(0, 10, 0)

# Load http assembly
Add-Type -AssemblyName System.Net.Http

# Create http client handler
$httpClientHandler = New-Object System.Net.Http.HttpClientHandler
$httpClient = New-Object System.Net.Http.HttpClient $httpClientHandler
$httpClient.DefaultRequestHeaders.Add("X-Octopus-ApiKey", $octopusAPIKey)
$httpClient.Timeout = $timeout

# Get space
$space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName} 

# Open file stream
$fileStream = New-Object System.IO.FileStream($packageFile, [System.IO.FileMode]::Open)

# Create dispositon object
$contentDispositionHeaderValue = New-Object System.Net.Http.Headers.ContentDispositionHeaderValue "form-data"
$contentDispositionHeaderValue.Name = "fileData"
$contentDispositionHeaderValue.FileName = [System.IO.Path]::GetFileName($packageFile)

# Creat steam content
$streamContent = New-Object System.Net.Http.StreamContent $fileStream
$streamContent.Headers.ContentDisposition = $contentDispositionHeaderValue
$contentType = "multipart/form-data"
$streamContent.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue $contentType

$content = New-Object System.Net.Http.MultipartFormDataContent
$content.Add($streamContent)

# Upload package
$httpClient.PostAsync("$octopusURL/api/$($space.Id)/packages/raw?replace=false", $content).Result

if ($null -ne $fileStream)
{
    $fileStream.Close()
}