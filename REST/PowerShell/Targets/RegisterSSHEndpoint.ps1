$ErrorActionPreference = "Stop";

# Define working variables
$octopusURL = "https://your.octopus.app"
$octopusAPIKey = "API-KEY"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$spaceName = "Default"
$sshTargetName = "SSH target Name"
$sshHostnameOrIpAddress = "127.0.0.1"
$sshPort = "22"
$sshFingerPrint = "00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00"
# Account name to use to authenticate
$accountName = "Account name"

# List of environment names
$environmentNames = @("Development", "Test")
$environmentIds = @()

# List of target-roles to add
$roles = @("MyRole")
# Target tenant deployment participation - select either "Tenanted", "Untenanted", or "TenantedOrUntenanted"
$tenantedDeploymentParticipation = "Untenanted"

# List of Tenant names to connect to the target
$tenantNames = @()
$tenantIds = @()

# Get space
$spaces = Invoke-RestMethod -Uri "$octopusURL/api/spaces?partialName=$([uri]::EscapeDataString($spaceName))&skip=0&take=100" -Headers $header 
$space = $spaces.Items | Where-Object { $_.Name -eq $spaceName }

# Get environment Ids
$environments = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/environments/all" -Headers $header) | Where-Object { $environmentNames -contains $_.Name }
foreach ($environment in $environments) {
  $environmentIds += $environment.Id
}

# Get tenants
$allTenants = (Invoke-RestMethod -Method Get -Uri "$octopusUrl/api/$($space.Id)/tenants/all" -Headers $header)

foreach ($tenantName in $tenantNames) {
  # Exchange tenant name for tenant ID
  $tenant = $allTenants | Where-Object { $_.name -eq $tenantName }

  # Associate tenant ID to deployment target
  $tenantIds += ($tenant.Id)
}

# Get account
$accounts = Invoke-RestMethod -Uri "$octopusURL/api/$($space.Id)/accounts?partialName=$([uri]::EscapeDataString($accountName))&skip=0&take=100" -Headers $header 
$account = $accounts.Items | Where-Object { $_.Name -eq $accountName }

$sshTarget = @{
  Name                            = $sshTargetName
  IsDisabled                      = $False
  HealthStatus                    = "Unknown"
  IsInProcess                     = $True
  Endpoint                        = @{
    CommunicationStyle = "Ssh"
    Name               = ""
    Uri                = "ssh://$($sshHostnameOrIpAddress):$($sshPort)/"
    Host               = $sshHostnameOrIpAddress
    Port               = $sshPort
    Fingerprint        = $sshFingerPrint
    DotNetCorePlatform = "linux-x64"
    HostKeyAlgorithm   = "ssh-ed25519"
    AccountId          = $account.Id
  }
  TenantedDeploymentParticipation = $tenantedDeploymentParticipation
  EnvironmentIds                  = $environmentIds
  Roles                           = $roles
  TenantIds                       = $tenantIds
}

$machine = Invoke-RestMethod "$OctopusUrl/api/$($space.Id)/machines" -Headers $header -Method Post -Body ($sshTarget | ConvertTo-Json -Depth 10)
Write-Host "Created machine $($machine.Id)"