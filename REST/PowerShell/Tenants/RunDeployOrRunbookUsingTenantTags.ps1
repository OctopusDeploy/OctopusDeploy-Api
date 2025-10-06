[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$OctopusUrl,
    
    [Parameter(Mandatory=$true)]
    [Security.SecureString]$ApiKey,
    
    [Parameter(Mandatory=$true)]
    [string]$SpaceName,
    
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,
    
    [Parameter(Mandatory=$false)]
    [string]$RunbookName,
    
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$TenantTag,
    
    [Parameter(Mandatory=$false)]
    [string]$Release,
    
    # Optional deployment/runbook parameters
    [Parameter(Mandatory=$false)]
    [string[]]$SkipActions = @(),
    
    [Parameter(Mandatory=$false)]
    [string[]]$SpecificMachineIds = @(),
    
    [Parameter(Mandatory=$false)]
    [string[]]$ExcludedMachineIds = @(),
    
    [Parameter(Mandatory=$false)]
    [bool]$ForcePackageDownload = $false,
    
    [Parameter(Mandatory=$false)]
    [bool]$ForcePackageRedeployment = $false,
    
    [Parameter(Mandatory=$false)]
    [hashtable]$FormValues = @{},
    
    [Parameter(Mandatory=$false)]
    [string]$QueueTime = $null,
    
    [Parameter(Mandatory=$false)]
    [string]$QueueTimeExpiry = $null,
    
    [Parameter(Mandatory=$false)]
    [bool]$UseGuidedFailure = $false,
    
    [Parameter(Mandatory=$false)]
    [string]$RunbookSnapshotId = $null
)

# Function to convert SecureString to plain text for API calls (kept secure in memory)
function ConvertFrom-SecureStringToPlainText {
    param([Security.SecureString]$SecureString)
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

# Function to mask API key in logs
function Write-SafeVerbose {
    param([string]$Message, [string]$ApiKeyPlain)
    if ($ApiKeyPlain) {
        $Message = $Message -replace [regex]::Escape($ApiKeyPlain), "***REDACTED***"
    }
    Write-Verbose $Message
}

# Function to validate SemVer format
function Test-SemVer {
    param([string]$Version)
    $semVerPattern = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'
    return $Version -match $semVerPattern
}

# Function to validate URL protocol
function Test-UrlProtocol {
    param([string]$Url)
    try {
        $uri = [System.Uri]$Url
        return ($uri.Scheme -eq 'http' -or $uri.Scheme -eq 'https')
    } catch {
        return $false
    }
}

# Function to make API calls with error handling
function Invoke-OctopusApi {
    param(
        [string]$Url,
        [string]$Method = "GET",
        [hashtable]$Headers,
        [object]$Body,
        [string]$ApiKeyPlain
    )
    
    Write-SafeVerbose "API Call: $Method $Url" -ApiKeyPlain $ApiKeyPlain
    
    if ($Body) {
        $bodyJson = $Body | ConvertTo-Json -Depth 10
        Write-SafeVerbose "Request Body: $bodyJson" -ApiKeyPlain $apiKeyPlain
    }
    
    try {
        $params = @{
            Uri = $Url
            Method = $Method
            Headers = $Headers
            ContentType = "application/json"
        }
        
        if ($Body) {
            $params.Body = ($Body | ConvertTo-Json -Depth 10)
        }
        
        $response = Invoke-RestMethod @params
        
        Write-Verbose "Response: $($response | ConvertTo-Json -Depth 10)"
        
        return $response
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $errorMessage = $_.Exception.Message
        $errorBody = ""
        
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $errorBody = $reader.ReadToEnd()
            $reader.Close()
        }
        
        # Always log non-200 responses without requiring verbose
        Write-Host "`n=== API Call Failed ===" -ForegroundColor Red
        Write-Host "Status Code: $statusCode" -ForegroundColor Red
        Write-Host "URL: $Url" -ForegroundColor Red
        Write-Host "Method: $Method" -ForegroundColor Red
        Write-Host "Error Message: $errorMessage" -ForegroundColor Red
        if ($errorBody) {
            Write-Host "Response Body: $errorBody" -ForegroundColor Red
        }
        Write-Host "==================`n" -ForegroundColor Red
        
        Write-Error "API call failed with status code $statusCode"
        Write-Error "URL: $Url"
        Write-Error "Method: $Method"
        Write-Error "Error Message: $errorMessage"
        Write-Error "Response Body: $errorBody"
        
        throw "API call failed: $errorMessage"
    }
}

# Main script execution
Write-Verbose "Starting Octopus API script execution"
Write-Verbose "Space Name: $SpaceName"
Write-Verbose "Project Name: $ProjectName"

# Determine operation mode and validate required parameters
if ($RunbookName) {
    Write-Verbose "Runbook Name: $RunbookName (Runbook execution mode)"
    if ($RunbookSnapshotId) {
        Write-Verbose "Runbook Snapshot ID: $RunbookSnapshotId"
    }
} else {
    Write-Verbose "No runbook specified (Deployment mode)"
    if (-not $Release) {
        Write-Error "Release parameter is required for deployments. Please provide a release version."
        exit 1
    }
    Write-Verbose "Release: $Release"
}

Write-Verbose "Environment: $Environment"
Write-Verbose "Tenant Tag: $TenantTag"

# Log optional parameters if provided
if ($SkipActions.Count -gt 0) {
    Write-Verbose "Skip Actions: $($SkipActions -join ', ')"
}
if ($SpecificMachineIds.Count -gt 0) {
    Write-Verbose "Specific Machine IDs: $($SpecificMachineIds -join ', ')"
}
if ($ExcludedMachineIds.Count -gt 0) {
    Write-Verbose "Excluded Machine IDs: $($ExcludedMachineIds -join ', ')"
}
if ($ForcePackageDownload) {
    Write-Verbose "Force Package Download: Enabled"
}
if ($ForcePackageRedeployment) {
    Write-Verbose "Force Package Redeployment: Enabled"
}
if ($FormValues.Count -gt 0) {
    $formValuesMsg = "Form Values: $($FormValues.Count) values provided"
    Write-Verbose $formValuesMsg
}
if ($QueueTime) {
    Write-Verbose "Queue Time: $QueueTime"
}
if ($QueueTimeExpiry) {
    Write-Verbose "Queue Time Expiry: $QueueTimeExpiry"
}
if ($UseGuidedFailure) {
    Write-Verbose "Use Guided Failure: Enabled"
}

# Convert SecureString to plain text for API usage
try {
    $apiKeyPlain = ConvertFrom-SecureStringToPlainText -SecureString $ApiKey
} catch {
    Write-Error "Failed to convert API key: $_"
    exit 1
}

# Validate Octopus URL protocol
try {
    Write-Verbose "Validating Octopus URL protocol..."
    if (-not (Test-UrlProtocol -Url $OctopusUrl)) {
        throw "Invalid Octopus URL: Must use http:// or https:// protocol"
    }
    Write-SafeVerbose "Octopus URL: $OctopusUrl" -ApiKeyPlain $apiKeyPlain
} catch {
    Write-Error "URL validation failed: $_"
    exit 1
}

# Validate SemVer format for release
if ($Release) {
    try {
        Write-Verbose "Validating release version format..."
        if (-not (Test-SemVer -Version $Release)) {
            throw "Invalid release version: Must be valid SemVer format (e.g., 1.0.0, 2.1.3-beta, 1.0.0+build123)"
        }
        Write-Verbose "Release version validated: $Release"
    } catch {
        Write-Error "Release validation failed: $_"
        exit 1
    }
}

# Set up header for API calls
$header = @{
    "X-Octopus-ApiKey" = $apiKeyPlain
}
Write-Verbose "API header configured"

# Ensure URL doesn't end with trailing slash
$OctopusUrl = $OctopusUrl.TrimEnd('/')

# Ensure URL ends with /api
if (-not $OctopusUrl.EndsWith('/api')) {
    $OctopusUrl = "$OctopusUrl/api"
    Write-Verbose "Added /api to Octopus URL"
}
Write-Verbose "Base Octopus API URL: $OctopusUrl"

# Step 0: Get space ID
try {
    Write-Verbose "Fetching space ID for: $SpaceName"
    $spacesUrl = "$OctopusUrl/spaces/all"
    $spacesResponse = Invoke-OctopusApi -Url $spacesUrl -Headers $header -ApiKeyPlain $apiKeyPlain
    
    # Filter spaces by name to find exact match
    $matchedSpace = $spacesResponse | Where-Object { $_.Name -eq $SpaceName }
    
    if (-not $matchedSpace) {
        throw "Space not found: $SpaceName"
    }
    
    $spaceId = $matchedSpace.Id
    Write-Verbose "Space ID: $spaceId"
    
    # Update OctopusUrl to include space ID
    $OctopusUrl = "$OctopusUrl/$spaceId"
    Write-Verbose "Updated Octopus URL with space: $OctopusUrl"
} catch {
    Write-Error "Failed to retrieve space: $_"
    exit 1
}

# Step 1: Get project ID
try {
    Write-Verbose "Fetching project ID for: $ProjectName"
    $projectsUrl = "$OctopusUrl/projects/all"
    $projectsResponse = Invoke-OctopusApi -Url $projectsUrl -Headers $header -ApiKeyPlain $apiKeyPlain
    
    # Filter projects by name to find exact match
    $matchedProject = $projectsResponse | Where-Object { $_.Name -eq $ProjectName }
    
    if (-not $matchedProject) {
        throw "Project not found: $ProjectName"
    }
    
    $projectId = $matchedProject.Id
    Write-Verbose "Project ID: $projectId"
} catch {
    Write-Error "Failed to retrieve project: $_"
    exit 1
}

# If RunbookName is provided, get runbook ID
$runbookId = $null
$publishedRunbookSnapshotId = $null
if ($RunbookName) {
    try {
        Write-Verbose "Fetching runbook ID for: $RunbookName"
        $runbooksUrl = "$OctopusUrl/runbooks/all"
        $runbooksResponse = Invoke-OctopusApi -Url $runbooksUrl -Headers $header -ApiKeyPlain $apiKeyPlain
        
        # Filter runbooks by name and project to find exact match
        $matchedRunbook = $runbooksResponse | Where-Object { $_.Name -eq $RunbookName -and $_.ProjectId -eq $projectId }
        
        if (-not $matchedRunbook) {
            throw "Runbook not found: $RunbookName in project $ProjectName"
        }
        
        $runbookId = $matchedRunbook.Id
        Write-Verbose "Runbook ID: $runbookId"
        
        # Get the full runbook details to retrieve PublishedRunbookSnapshotId
        Write-Verbose "Fetching published runbook snapshot for runbook: $runbookId"
        $runbookDetailsUrl = "$OctopusUrl/runbooks/$runbookId"
        $runbookDetails = Invoke-OctopusApi -Url $runbookDetailsUrl -Headers $header -ApiKeyPlain $apiKeyPlain
        
        $publishedRunbookSnapshotId = $runbookDetails.PublishedRunbookSnapshotId
        
        if ($publishedRunbookSnapshotId) {
            Write-Verbose "Published Runbook Snapshot ID: $publishedRunbookSnapshotId"
        } else {
            Write-Verbose "No published runbook snapshot found for this runbook"
        }
    } catch {
        Write-Error "Failed to retrieve runbook: $_"
        exit 1
    }
}

# Step 2: Get tenants by tag
try {
    Write-Verbose "Fetching tenants with tag: $TenantTag"
    $tenantsUrl = "$OctopusUrl/tenants?tags=$TenantTag"
    $tenantsResponse = Invoke-OctopusApi -Url $tenantsUrl -Headers $header -ApiKeyPlain $apiKeyPlain
    
    if (-not $tenantsResponse.Items -or $tenantsResponse.Items.Count -eq 0) {
        throw "No tenants found with tag: $TenantTag"
    }
    
    # Store tenant information including their IDs and names for better logging
    $tenants = @($tenantsResponse.Items | ForEach-Object { 
        @{
            Id = $_.Id
            Name = $_.Name
            ProjectEnvironments = $_.ProjectEnvironments
        }
    })
    Write-Verbose "Found $($tenants.Count) tenants: $($tenants.Name -join ', ')"
} catch {
    Write-Error "Failed to retrieve tenants: $_"
    exit 1
}

# Step 3: Get environment ID
try {
    Write-Verbose "Fetching environment ID for: $Environment"
    $environmentsUrl = "$OctopusUrl/environments/all"
    $environmentsResponse = Invoke-OctopusApi -Url $environmentsUrl -Headers $header -ApiKeyPlain $apiKeyPlain
    
    # Filter environments by name to find exact match
    $matchedEnvironment = $environmentsResponse | Where-Object { $_.Name -eq $Environment }
    
    if (-not $matchedEnvironment) {
        throw "Environment not found: $Environment"
    }
    
    $environmentId = $matchedEnvironment.Id
    Write-Verbose "Environment ID: $environmentId"
} catch {
    Write-Error "Failed to retrieve environment: $_"
    exit 1
}

# Step 3.5: Get Release ID if doing deployment
$releaseId = $null
if (-not $RunbookName -and $Release) {
    try {
        Write-Verbose "Fetching release ID for version: $Release"
        $releasesUrl = "$OctopusUrl/projects/$projectId/releases"
        $releasesResponse = Invoke-OctopusApi -Url $releasesUrl -Headers $header -ApiKeyPlain $apiKeyPlain
        
        # Filter releases by version to find exact match
        $matchedRelease = $releasesResponse.Items | Where-Object { $_.Version -eq $Release }
        
        if (-not $matchedRelease) {
            throw "Release not found: $Release for project $ProjectName"
        }
        
        $releaseId = $matchedRelease.Id
        Write-Verbose "Release ID: $releaseId"
    } catch {
        Write-Error "Failed to retrieve release: $_"
        exit 1
    }
}

# Step 3.6: Validate tenants are connected to the target environment
Write-Verbose "Validating tenant-environment associations..."
$validTenants = @()
$skippedTenants = @()

foreach ($tenant in $tenants) {
    # Check if this tenant has the project connected to the target environment
    $projectEnvironments = $tenant.ProjectEnvironments
    
    # Check if the project-environment combination exists for this tenant
    $tenantHasEnvironment = $false
    
    if ($projectEnvironments -and $projectEnvironments.PSObject.Properties.Name -contains $projectId) {
        $projectEnvs = $projectEnvironments.$projectId
        if ($projectEnvs -contains $environmentId) {
            $tenantHasEnvironment = $true
        }
    }
    
    if ($tenantHasEnvironment) {
        $validTenants += $tenant
        Write-Verbose "Tenant '$($tenant.Name)' is connected to environment '$Environment' for project '$ProjectName'"
    } else {
        $skippedTenants += $tenant
        Write-Warning "Tenant '$($tenant.Name)' (ID: $($tenant.Id)) was found with tag '$TenantTag' but is NOT connected to environment '$Environment' for project '$ProjectName'. This tenant will be skipped."
    }
}

if ($validTenants.Count -eq 0) {
    Write-Error "No tenants found that are both tagged with '$TenantTag' AND connected to environment '$Environment' for project '$ProjectName'"
    exit 1
}

Write-Host "Tenant validation complete: $($validTenants.Count) valid, $($skippedTenants.Count) skipped" -ForegroundColor Cyan
$tenants = $validTenants

# Step 4: Execute deploy or runbook based on whether RunbookName is provided - loop through each tenant
$successCount = 0
$failureCount = 0
$results = @()

# Explicitly set operation mode as a string
if ([string]::IsNullOrEmpty($RunbookName)) {
    $operationMode = "DEPLOYMENT"
} else {
    $operationMode = "RUNBOOK"
}

if ($operationMode -eq "RUNBOOK") {
    Write-Verbose "Executing runbook for each tenant..."
    Write-Host "Mode: Runbook Execution" -ForegroundColor Cyan
    
    foreach ($tenant in $tenants) {
        Write-Verbose "Processing runbook run for tenant: $($tenant.Name) ($($tenant.Id))"
        Write-Verbose "  Project: $ProjectName"
        Write-Verbose "  Runbook: $RunbookName"
        Write-Verbose "  Environment: $Environment ($environmentId)"
        Write-Verbose "  Tenant Tag: $TenantTag"
        
        $runbookRunUrl = "$OctopusUrl/runbookRuns"
        
        # Determine which snapshot to use: provided parameter or published snapshot
        $snapshotToUse = if ($RunbookSnapshotId) { 
            $RunbookSnapshotId 
        } else { 
            $publishedRunbookSnapshotId 
        }
        
        if (-not $snapshotToUse) {
            Write-Error "No runbook snapshot available for runbook '$RunbookName'. The runbook must have a published snapshot or you must provide a RunbookSnapshotId parameter."
            $failureCount++
            $results += @{
                TenantId = $tenant.Id
                TenantName = $tenant.Name
                Status = "Failed"
                Error = "No runbook snapshot available"
                ProjectName = $ProjectName
                RunbookName = $RunbookName
                Environment = $Environment
                TenantTag = $TenantTag
            }
            continue
        }
        
        $runbookBody = @{
            RunbookId = $runbookId
            RunbookSnapshotId = $snapshotToUse
            EnvironmentId = $environmentId
            TenantId = $tenant.Id
            Comments = "Runbook run for project: $ProjectName, runbook: $RunbookName, environment: $Environment, tenant tag: $TenantTag"
            SkipActions = $SkipActions
            SpecificMachineIds = $SpecificMachineIds
            ExcludedMachineIds = $ExcludedMachineIds
            ForcePackageDownload = $ForcePackageDownload
            FormValues = $FormValues
            QueueTime = $QueueTime
            QueueTimeExpiry = $QueueTimeExpiry
            UseGuidedFailure = $UseGuidedFailure
        }
        
        Write-Verbose "  Using Runbook Snapshot: $snapshotToUse"
        Write-Verbose "Posting runbook run for tenant $($tenant.Id)..."
        
        $runbookResponse = Invoke-OctopusApi -Url $runbookRunUrl -Method "POST" -Headers $header -Body $runbookBody -ApiKeyPlain $apiKeyPlain
        
        if ($runbookResponse) {
            Write-Host "[SUCCESS] Runbook run successfully initiated for tenant $($tenant.Name)" -ForegroundColor Green
            Write-Verbose "  Runbook Run ID: $($runbookResponse.Id)"
            
            $successCount++
            $results += @{
                TenantId = $tenant.Id
                TenantName = $tenant.Name
                Status = "Success"
                Id = $runbookResponse.Id
                ProjectName = $ProjectName
                RunbookName = $RunbookName
                Environment = $Environment
                TenantTag = $TenantTag
            }
        } else {
            Write-Error "Failed to run runbook for tenant $($tenant.Name) ($($tenant.Id))"
            $failureCount++
            $results += @{
                TenantId = $tenant.Id
                TenantName = $tenant.Name
                Status = "Failed"
                Error = "API call returned no response"
                ProjectName = $ProjectName
                RunbookName = $RunbookName
                Environment = $Environment
                TenantTag = $TenantTag
            }
        }
    }
}

if ($operationMode -eq "DEPLOYMENT") {
    Write-Verbose "Executing deployment for each tenant..."
    Write-Host "Mode: Deployment Execution" -ForegroundColor Cyan
    
    foreach ($tenant in $tenants) {
        Write-Verbose "Processing deployment for tenant: $($tenant.Name) ($($tenant.Id))"
        Write-Host "  > Deploying to tenant: $($tenant.Name)" -ForegroundColor Yellow
        
        $deploymentsUrl = "$OctopusUrl/deployments"
        
        $deploymentBody = @{
            ReleaseId = $releaseId
            EnvironmentId = $environmentId
            TenantId = $tenant.Id
            Comments = "Deployment for project: $ProjectName, environment: $Environment, release: $Release, tenant tag: $TenantTag"
            SkipActions = $SkipActions
            SpecificMachineIds = $SpecificMachineIds
            ExcludedMachineIds = $ExcludedMachineIds
            ForcePackageDownload = $ForcePackageDownload
            ForcePackageRedeployment = $ForcePackageRedeployment
            FormValues = $FormValues
            QueueTime = $QueueTime
            QueueTimeExpiry = $QueueTimeExpiry
            UseGuidedFailure = $UseGuidedFailure
        }
        
        Write-Verbose "Posting deployment for tenant $($tenant.Id)..."
        
        $deploymentResponse = Invoke-OctopusApi -Url $deploymentsUrl -Method "POST" -Headers $header -Body $deploymentBody -ApiKeyPlain $apiKeyPlain
        
        if ($deploymentResponse) {
            Write-Host "[SUCCESS] Deployment successfully initiated for tenant $($tenant.Name)" -ForegroundColor Green
            Write-Verbose "  Deployment ID: $($deploymentResponse.Id)"
            
            $successCount++
            $results += @{
                TenantId = $tenant.Id
                TenantName = $tenant.Name
                Status = "Success"
                Id = $deploymentResponse.Id
                ProjectName = $ProjectName
                Environment = $Environment
                Release = $Release
                TenantTag = $TenantTag
            }
        } else {
            Write-Error "Failed to deploy for tenant $($tenant.Name) ($($tenant.Id))"
            $failureCount++
            $results += @{
                TenantId = $tenant.Id
                TenantName = $tenant.Name
                Status = "Failed"
                Error = "API call returned no response"
                ProjectName = $ProjectName
                Environment = $Environment
                Release = $Release
                TenantTag = $TenantTag
            }
        }
    }
}

# Summary
Write-Host "`n=== Execution Summary ===" -ForegroundColor Cyan
$operationType = if ($operationMode -eq "RUNBOOK") { "Runbook Run" } else { "Deployment" }
Write-Host "Operation Type: $operationType" -ForegroundColor Cyan
Write-Host "Space: $SpaceName" -ForegroundColor Cyan
Write-Host "Project: $ProjectName" -ForegroundColor Cyan
if ($operationMode -eq "RUNBOOK") {
    Write-Host "Runbook: $RunbookName" -ForegroundColor Cyan
} else {
    Write-Host "Release: $Release" -ForegroundColor Cyan
}
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "Tenant Tag: $TenantTag" -ForegroundColor Cyan
Write-Host "Total Tenants: $($tenants.Count)" -ForegroundColor Cyan
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { "Red" } else { "Green" })

# Display results
Write-Verbose "`nDetailed Results:"
foreach ($result in $results) {
    Write-Verbose "  Tenant: $($result.TenantName) ($($result.TenantId))"
    Write-Verbose "    Status: $($result.Status)"
    Write-Verbose "    Project: $($result.ProjectName)"
    if ($result.RunbookName) {
        Write-Verbose "    Runbook: $($result.RunbookName)"
    } elseif ($result.Release) {
        Write-Verbose "    Release: $($result.Release)"
    }
    Write-Verbose "    Environment: $($result.Environment)"
    Write-Verbose "    Tenant Tag: $($result.TenantTag)"
    if ($result.Id) {
        Write-Verbose "    ID: $($result.Id)"
    }
    if ($result.Error) {
        Write-Verbose "    Error: $($result.Error)"
    }
}

# Exit with error if any failures occurred
if ($failureCount -gt 0) {
    $errorMessage = "Script completed with $failureCount failures"
    Write-Error $errorMessage
    exit 1
}

Write-Verbose "Script completed successfully"

# Cleanup sensitive data
if ($apiKeyPlain) {
    $apiKeyPlain = $null
    [System.GC]::Collect()
}

exit 0