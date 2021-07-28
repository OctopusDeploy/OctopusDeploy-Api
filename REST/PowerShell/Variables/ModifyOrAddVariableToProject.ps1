function Set-OctopusVariable {
    param(
        $octopusURL = "https://xxx.octopus.app/", # Octopus Server URL
        $octopusAPIKey = "API-xxx",               # API key goes here
        $projectName = "xxx",                     # Replace with your project name
        $spaceName = "Default",                   # Replace with the name of the space you are working in
        $environment = $null,                     # Replace with the name of the environment you want to scope the variables to
        $varName = "",                            # Replace with the name of the variable
        $varValue = ""                            # Replace with the value of the variable
    )

    # Defines header for API call
    $header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

    # Get space
    $space = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/spaces/all" -Headers $header) | Where-Object {$_.Name -eq $spaceName}

    # Get project
    $project = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/projects/all" -Headers $header) | Where-Object {$_.Name -eq $projectName}

    # Get project variables
    $projectVariables = Invoke-RestMethod -Method Get -Uri "$octopusURL/api/$($space.Id)/variables/$($project.VariableSetId)" -Headers $header

    # Get environment to scope to
    $environmentObj = $projectVariables.ScopeValues.Environments | Where { $_.Name -eq $environment } | Select -First 1

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

    # Check to see if variable is already present
    $variablesWithSameName = $projectVariables.Variables | Where-Object {$_.Name -eq $variable.Name}

    if (@($variablesWithSameName.Name).Length -eq 1){
        # There is only one variable with the same name
        if ($variablesWithSameName.Scope.Environment -like $variable.Scope.Environment){
            # The existing variable has the same scope: remove the olkd value
            $projectVariables.Variables = $projectVariables.Variables | Where-Object { $_.id -notlike $variablesWithSameName.id}
        }  
        if ($environmentObj -eq $null){
            # There is no scope
            $unscopedVariablesWithSameName = @($variablesWithSameName) | Where-Object { $_.Scope -like $null}
            $projectVariables.Variables = $projectVariables.Variables | Where-Object { $_.id -notin @($unscopedVariablesWithSameName.id)}
        } 
    }
    if (@($variablesWithSameName.Name).Length -gt 1){
        Write-output "65" 
        # There are multiple variables with the same name
        if (@($variablesWithSameName.Scope.Environment) -contains $variable.Scope.Environment){
            # At least one of the existing variables is scoped to this environment, removing all with same scope
            $variablesWithMatchingNameAndScope = $variablesWithSameName | Where-Object { $_.Scope.Environment -like $variable.Scope.Environment}
            $projectVariables.Variables = $projectVariables.Variables | Where-Object { $_.id -notin @($variablesWithMatchingNameAndScope.id)}
        }
        if ($environmentObj -eq $null){
            # There is no scope
            $unscopedVariablesWithSameName = $variablesWithSameName | Where-Object { $_.Scope -like $null}
            $projectVariables.Variables = $projectVariables.Variables | Where-Object { $_.id -notin @($unscopedVariablesWithSameName.id)}
        }  
    }
    
    # Adding the new value
    $projectVariables.Variables += $variable
    
    # Update the collection
    Invoke-RestMethod -Method Put -Uri "$octopusURL/api/$($space.Id)/variables/$($project.VariableSetId)" -Headers $header -Body ($projectVariables | ConvertTo-Json -Depth 10)
}

Set-OctopusVariable -octopusURL "https://xxx.octopus.app/" -octopusAPIKey "API-xxx" -projectName "hello_world" -varName "name" -varValue "alex" -environment "Production"
