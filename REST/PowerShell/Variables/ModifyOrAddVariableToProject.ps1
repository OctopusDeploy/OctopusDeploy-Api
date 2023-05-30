function Set-OctopusVariable {
    param(
        $octopusURL = "https://xxx.octopus.app/", # Octopus Server URL
        $octopusAPIKey = "API-xxx",               # API key goes here
        $projectName = "",                        # Replace with your project name
        $spaceName = "Default",                   # Replace with the name of the space you are working in
        $environment = $null,                     # Replace with the name of the environment you want to scope the variables to
        $varName = "",                            # Replace with the name of the variable
        $varValue = "",                           # Replace with the value of the variable
        $gitRefOrBranchName = $null               # Set this value if you are storing a plain-text variable and the project is version controlled. If no value is set, the default branch will be used.
    )

    # Defines header for API call
    $header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get project
    $project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

    # Get project variables
    $databaseVariables = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/variables/$($project.VariableSetId)" -Headers $header
    
    if($project.IsVersionControlled -eq $true) {
        if ([string]::IsNullOrWhiteSpace($gitRefOrBranchName)) {
            $gitRefOrBranchName = $project.PersistenceSettings.DefaultBranch
            Write-Output "Using $($gitRefOrBranchName) as the gitRef for this operation."
        }
        $versionControlledVariables = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/$($gitRefOrBranchName)/variables" -Headers $header
    }

    # Get environment values to scope to
    $environmentObj = $databaseVariables.ScopeValues.Environments | Where { $_.Name -eq $environment } | Select -First 1

    # Define values for variable
    $variable = @{
        Name = $varName  # Replace with a variable name
        Value = $varValue # Replace with a value
        Type = "String"
        IsSensitive = $false
        Scope = @{ 
            Environment = @(
                $environmentObj.Id
                )
            }
    }
    # Assign the correct variables based on version-controlled project or not
    $projectVariables = $databaseVariables

    if($project.IsVersionControlled -eq $True -and $variable.IsSensitive -eq $False) {
        $projectVariables = $versionControlledVariables
    }

    # Check to see if variable is already present. If so, removing old version(s).
    $variablesWithSameName = $projectVariables.Variables | Where-Object {$_.Name -eq $variable.Name}
    
    if ($environmentObj -eq $null){
        # The variable is not scoped to an environment
        $unscopedVariablesWithSameName = $variablesWithSameName | Where-Object { $_.Scope -like $null}
        $projectVariables.Variables = $projectVariables.Variables | Where-Object { $_.id -notin @($unscopedVariablesWithSameName.id)}
    } 
    
    if (@($variablesWithSameName.Scope.Environment) -contains $variable.Scope.Environment){
        # At least one of the existing variables with the same name is scoped to the same environment, removing all matches
        $variablesWithMatchingNameAndScope = $variablesWithSameName | Where-Object { $_.Scope.Environment -like $variable.Scope.Environment}
        $projectVariables.Variables = $projectVariables.Variables | Where-Object { $_.id -notin @($variablesWithMatchingNameAndScope.id)}
    }
    
    # Adding the new value
    $projectVariables.Variables += $variable
    
    # Update the collection
    if($project.IsVersionControlled -eq $True -and $variable.IsSensitive -eq $False) {
        Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/projects/$($project.Id)/$($gitRefOrBranchName)/variables" -Headers $header -Body ($projectVariables | ConvertTo-Json -Depth 10)    
    }
    else {
        Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/variables/$($project.VariableSetId)" -Headers $header -Body ($projectVariables | ConvertTo-Json -Depth 10)
    }
    
}

Set-OctopusVariable -octopusURL "https://xxx.octopus.app/" -octopusAPIKey "API-xxx" -projectName "hello_world" -varName "name" -varValue "alex" -environment "Production" -gitRefOrBranchName $null
