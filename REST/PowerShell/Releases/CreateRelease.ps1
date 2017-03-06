# This script will create a new release for a project

$OctopusURL = "" # URL of Octopus Server
$OctopusAPIKey = "" # API Key to authenticate to Octopus Server

$header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }

# customise the fields below as required:
$body = @{
  ProjectId = "Projects-1"
  ChannelId = "Channels-1"
  Version = "0.0.4"
  ReleaseNotes = "the release notes"
  SelectedPackages = @(
    @{
      StepName = "Deploy"
      Version = "1.0.18"
    }
  )
}

try
{
  Invoke-WebRequest $OctopusURL/api/releases?ignoreChannelRules=false -Method POST -Headers $header -Body ($body | ConvertTo-Json)
}
catch
{
  $Result = $_.Exception.Response.GetResponseStream()
  $Reader = New-Object System.IO.StreamReader($result)
  $ResponseBody = $Reader.ReadToEnd();
  $Response = $ResponseBody | ConvertFrom-Json
  $Response.Errors
}
