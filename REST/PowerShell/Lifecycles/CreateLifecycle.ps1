#Connection Info
$OctopusAPIKey = "" #Your API KEy
$OctopusURL = "" #Your Octopus Server URL

$header = @{ "X-Octopus-ApiKey" = $OctopusAPIKey }

$body = @'
{
    "Name": "MyNewLifecycle",
    "ReleaseRetentionPolicy": {
        "ShouldKeepForever": true,
        "QuantityToKeep": 0,
        "Unit": "Items"
    },
    "TentacleRetentionPolicy": {
        "ShouldKeepForever": true,
        "QuantityToKeep": 0,
        "Unit": "Items"
    },
    "Description": "My lifecycle description",
    "Phases": [
        {
            "Name": "MyFirstPhase",
            "MinimumEnvironmentsBeforePromotion": 0,
            "AutomaticDeploymentTargets": ["Environments-1"],
            "OptionalDeploymentTargets": [ ],
            
            "ReleaseRetentionPolicy": {
                "ShouldKeepForever": false,
                "QuantityToKeep": 3,
                "Unit": "Items"
            },
            "TentacleRetentionPolicy": {
                "ShouldKeepForever": false,
                "QuantityToKeep": 3,
                "Unit": "Items"
            }
        },
        {
            "Name": "MySecondPhase",
            "MinimumEnvironmentsBeforePromotion": 0,
            "AutomaticDeploymentTargets": [ ],
            "OptionalDeploymentTargets": ["Environments-20"],
            
            "ReleaseRetentionPolicy": {
                "ShouldKeepForever": false,
                "QuantityToKeep": "6",
                "Unit": "Items"
            },
            "TentacleRetentionPolicy": {
                "ShouldKeepForever": false,
                "QuantityToKeep": "6",
                "Unit": "Items"
            }
        }
    ]
}
'@

Invoke-RestMethod $OctopusURL/api/lifecycles -Method Post -Headers $header -Body $body