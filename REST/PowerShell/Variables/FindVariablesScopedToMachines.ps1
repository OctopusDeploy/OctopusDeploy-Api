$OctopusUrl = "https://YOUR INSTANCE URL"
$OctopusApiKey = "YOUR API KEY"

function Invoke-OctopusApi
{
    param
    (
        $octopusUrl,
        $endPoint,
        $spaceId,
        $apiKey,
        $method,
        $item
    )
    
    if ([string]::IsNullOrWhiteSpace($SpaceId))
    {
        $url = "$OctopusUrl/api/$EndPoint"
    }
    else
    {
        $url = "$OctopusUrl/api/$spaceId/$EndPoint"    
    }  
    
    if ([string]::IsNullOrWhiteSpace($method))
    {
    	$method = "GET"
    }

    try
    {
        if ($null -eq $item)
        {
            Write-Verbose "No data to post or put, calling bog standard invoke-restmethod for $url"
            return Invoke-RestMethod -Method $method -Uri $url -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -ContentType 'application/json; charset=utf-8' -TimeoutSec 60
        }

        $body = $item | ConvertTo-Json -Depth 10
        Write-Verbose $body

        Write-Verbose "Invoking $method $url"
        return Invoke-RestMethod -Method $method -Uri $url -Headers @{"X-Octopus-ApiKey" = "$ApiKey" } -Body $body -ContentType 'application/json; charset=utf-8' -TimeoutSec 60
    }
    catch
    {
        Write-Host "There was an error making a $method call to $url.  All request information (JSON body specifically) are logged as verbose.  Please check that for more information." -ForegroundColor Red

        if ($null -ne $_.Exception.Response)
        {
            if ($_.Exception.Response.StatusCode -eq 401)
            {
                Write-Host "Unauthorized error returned from $url, please verify API key and try again" -ForegroundColor Red
            }
            elseif ($_.ErrorDetails.Message)
            {                
                Write-Host -Message "Error calling $url StatusCode: $($_.Exception.Response) $($_.ErrorDetails.Message)" -ForegroundColor Red
                Write-Host $_.Exception -ForegroundColor Red
            }            
            else 
            {
                Write-Host $_.Exception -ForegroundColor Red
            }
        }
        else
        {
            Write-Host $_.Exception -ForegroundColor Red
        }

        Exit 1
    }    
}

$spacesList = Invoke-OctopusApi -OctopusUrl $octopusUrl -endPoint "spaces?skip=0&take=1000" -spaceId $null -apiKey $OctopusApiKey -item $null -method "GET"

$foundVariables = @()

foreach ($space in $spacesList.Items)
{
    Write-Host "Checking all projects in $($space.Name)"

    $projectList = Invoke-OctopusApi -OctopusUrl $octopusUrl -endPoint "projects?skip=0&take=1000" -spaceId $space.Id -apiKey $OctopusApiKey -item $null -method "GET"
    foreach ($project in $projectList.Items)
    {
        Write-Host "Checking project $($project.Name) variables"
        $variablesList = Invoke-OctopusApi -OctopusUrl $octopusUrl -endPoint "variables/$($project.VariableSetId)" -spaceId $space.Id -apiKey $OctopusApiKey -item $null -method "GET"
        foreach ($variable in $variablesList.Variables)
        {
            if (Get-Member -InputObject $variable.Scope -Name "Machine" -MemberType Properties)
            {
                Write-Host "Found a machine-scoped variable"
                $foundVariables += "Variable $($variable.Name) in project $($project.Name) in space $($space.Name) has machine scoping."
            }
        }
    }

    $libraryVariableSetList = Invoke-OctopusApi -OctopusUrl $octopusUrl -endPoint "libraryvariablesets?contentType=Variables&skip=0&take=1000" -spaceId $space.Id -apiKey $OctopusApiKey -item $null -method "GET"
    foreach ($libraryVariableSet in $libraryVariableSetList.Items)
    {
        Write-Host "Checking library variable set $($libraryVariableSet.Name) variables"
        $variablesList = Invoke-OctopusApi -OctopusUrl $octopusUrl -endPoint "variables/$($libraryVariableSet.VariableSetId)" -spaceId $space.Id -apiKey $OctopusApiKey -item $null -method "GET"
        foreach ($variable in $variablesList.Variables)
        {
            if (Get-Member -InputObject $variable.Scope -Name "Machine" -MemberType Properties)
            {
                Write-Host "Found a machine-scoped variable"
                $foundVariables += "Variable $($variable.Name) in library variable set $($libraryVariableSet.Name) in space $($space.Name) has machine scoping."
            }
        }
    }
}

foreach ($item in $foundVariables)
{
    Write-Host $item
}