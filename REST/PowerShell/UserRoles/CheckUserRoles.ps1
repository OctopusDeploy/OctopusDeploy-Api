# Check that the built-in User Roles in your Octopus instance have the same permissions assigned as a new install of Octopus by checking it against a new install of Octopus.

# the "clean" instance of Octopus, to use as the desired state.
$desiredStateOctopusURL = "https://initial-state-octopus-instance/"
$desiredStateOctopusAPIKey = "API-xxxxx"
$desiredStateHeader = @{ "X-Octopus-ApiKey" = $desiredStateOctopusAPIKey }

# the Octopus instance you'd like to check
$octopusURL = "http://your-octopus-instance/"
$octopusAPIKey = "API-xxxx"
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

try
{
    Write-Host "====== Starting comparison ======="

    # Get user roles from desired state (unchanged from initial install) instance of Octopus
    $desiredStateUserRoles = (Invoke-RestMethod -Method Get -Uri "$desiredStateOctopusURL/api/userroles/all" -Headers $desiredStateHeader) | Where-Object {$_.CanBeDeleted -eq $false} 
    
    # Get user roles to check
    $userRoles = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/userroles/all" -Headers $header) | Where-Object {$_.CanBeDeleted -eq $false} 
    

    foreach ($userRole in $userRoles) {
        $dsUserRole = $desiredStateUserRoles | Where-Object { $_.Id -eq $userRole.Id }

        $comparisonResult = Compare-Object -ReferenceObject $dsUserRole.GrantedSpacePermissions -DifferenceObject $userRole.GrantedSpacePermissions #-PassThru

        if ($comparisonResult.Length -gt 0){
            
            Write-Host "$($userRole.Name): "

            foreach ($result in $comparisonResult) {
                if ($result.SideIndicator -eq "<="){
                    Write-Host "      - $($result.InputObject)  MISSING"
                } else {
                    Write-Host "      - $($result.InputObject)  ADDED"
                }
            }
        }
    }

    Write-Host "====== Comparison complete. ======="

}
catch
{
    Write-Host $_.Exception.Message
}



    
