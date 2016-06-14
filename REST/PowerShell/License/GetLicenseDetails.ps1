##CONFIG##

$OctopusAPIkey = "" #API Key. Needs to belong to a user with Admin permissions.
$OctopusURL = "" #Octopus URL
$LicenseLevel = "" #Accepted values are  "Team","Professional","Enterprise"

##PROCESS##
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$Projects = ((Invoke-WebRequest $OctopusURL/api/projects/all -Headers $header).content | ConvertFrom-Json).count
$Users = ((Invoke-WebRequest $OctopusURL/api/users/all -Headers $header).content | ConvertFrom-Json).count
$Machines = ((Invoke-WebRequest $OctopusURL/api/Machines/all -Headers $header).content | ConvertFrom-Json).count

switch ($LicenseLevel)
{
    'Professional' {
        $limit = 60
        Write-output "--Current status--"
        Write-Output "Projects: $Projects"
        Write-Output "Users: $Users"
        Write-Output "Machines: $Machines"

        Write-Output "Limit by license: $limit"
        $remaining = $limit - $Projects - $Users - $Machines
        Write-Output "Available 'things': $remaining"
        Write-Output "What are these things? read: https://github.com/OctopusDeploy/Issues/issues/1937  "
    }
    'Team' {
        $limit = 180
        Write-output "--Current status--"
        Write-Output "Projects: $Projects"
        Write-Output "Users: $Users"
        Write-Output "Machines: $Machines"

        Write-Output "Limit by license: $limit"
        $remaining = $limit - $Projects - $Users - $Machines
        Write-Output "Available 'things': $remaining"
        Write-Output "What are these things? read: https://github.com/OctopusDeploy/Issues/issues/1937  "
    }
    'Enterprise' {
        Write-output "--Current status--"
        Write-Output "Projects: $Projects"
        Write-Output "Users: $Users"
        Write-Output "Machines: $Machines"
        Write-Output "Limit by license: Unlimmited"
    }
    Default {Write-error "Unvalid value passed to `$LicenseLevel. Accepted values are 'Professional','Team','Enterprise'"}
}