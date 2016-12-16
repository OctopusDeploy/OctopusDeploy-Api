
$OctopusURI = ""
$OctopusAPIKey = ""

Add-Type -Path "" # Path to Newtonsoft.Json.dll
Add-Type -Path "" # Path to Octopus.Client.dll

$endpoint = new-object Octopus.Client.OctopusServerEndpoint $OctopusURI, $OctopusAPIKey
$repository = new-object Octopus.Client.OctopusRepository $endpoint
$environments = $repository.Environments.FindAll()

foreach($environment in $environments)
{
  $header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }
  Write-Output "Creating healthcheck task for environment '$($environment.Name)'"
  $body = @{
      Name = "Health"
      Description = "Checking health of all machines in environment '$($environment.Name)'"
      Arguments = @{
          Timeout= "00:05:00"
          EnvironmentId = $environment.Id
      }
  } | ConvertTo-Json

  # poll the task until it succeeds, fails, times-out or gets canceled
  $result = Invoke-RestMethod $OctopusURI/api/tasks -Method Post -Body $body -Headers $header
  while (($result.State -ne "Success") -and ($result.State -ne "Failed") -and ($result.State -ne "Canceled") -and ($result.State -ne "TimedOut")) {
    Write-Output "Polling for healthcheck completion. Status is '$($result.State)'"
    Start-Sleep -Seconds 5
    $result = Invoke-RestMethod "$OctopusURI$($result.Links.Self)" -Headers $header
  }
  Write-Output "Healthcheck completed with status '$($result.State)'"
}
