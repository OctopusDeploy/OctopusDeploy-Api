##CONFIG##
$OctopusAPIkey = "API-XXXXXXXXXXXXX" #Your Octopus API Key
$OctopusURL = "https://yourOctoURL"
$header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }

## FETCH INTERRUPTIONS ##
$interruptionsUri = "$OctopusURL/octopus/api/interruptions"
$interruptions = Invoke-RestMethod -Uri $interruptionsUri -Method Get -Headers $header

## FILTER FOR PENDING GUIDED FAILURES ##
$pendingFailures = $interruptions.Items | Where-Object { $_.IsPending -and $_.Type -eq "GuidedFailure" }

# Group by unique DeploymentId (from RelatedDocumentIds)
$uniqueFailures = @{}
foreach ($item in $pendingFailures) {
    $deploymentId = $item.RelatedDocumentIds | Where-Object { $_ -like "Deployments-*" }
    if (![string]::IsNullOrEmpty($deploymentId) -and -not $uniqueFailures.ContainsKey($deploymentId)) {
        $uniqueFailures[$deploymentId] = $item
    }
}

if ($uniqueFailures.Count -eq 0) {
    Write-Host "No deployments with pending guided failures found..."
} else {
    foreach ($entry in $uniqueFailures.GetEnumerator()) {
        $item = $entry.Value
        $deploymentId = $entry.Key

        # Get Environment ID
        $environmentId = $item.RelatedDocumentIds | Where-Object { $_ -like "Environments-*" }
        if ([string]::IsNullOrEmpty($environmentId)) {
            Write-Host "No EnvironmentId found, skipping..."
            continue
        }

        # Get Environment Name
        $environmentUri = "$OctopusURL/octopus/api/environments/$environmentId"
        $environmentResponse = Invoke-RestMethod -Uri $environmentUri -Method Get -Headers $header
        $environmentName = $environmentResponse.Name
        Write-Host "Environment: $environmentName"

        # Get Tenant ID
        $tenantId = $item.RelatedDocumentIds | Where-Object { $_ -like "Tenants-*" }
        if (![string]::IsNullOrEmpty($tenantId)) {
            $tenantUri = "$OctopusURL/octopus/api/tenants/$tenantId"
            $tenantResponse = Invoke-RestMethod -Uri $tenantUri -Method Get -Headers $header
            $tenantName = $tenantResponse.Name
        } else {
            $tenantName = "No tenant"
        }

        Write-Host "Tenant: $tenantName"

        # Check if environment is one of the targets
        if ($environmentName -in @("Dev", "QA")) {
            Write-Host ">>> MATCH FOUND: $environmentName - performing action..."

            # Send Slack Notification or do something else if desired
            $slackWebhookUrl = "https://hooks.yourSlackWebhook"
            $slackPayload = @{
                text = "Manual intervention (GuidedFailure) detected in *$environmentName* for tenant *$tenantName* - please investigate."
            } | ConvertTo-Json

            Invoke-RestMethod -Uri $slackWebhookUrl -Method Post -Body $slackPayload -ContentType 'application/json'
        } else {
            Write-Host "Skipping environment: $environmentName"
        }
    }
}
