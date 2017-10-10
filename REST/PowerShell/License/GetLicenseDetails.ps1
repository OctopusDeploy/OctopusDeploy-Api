##CONFIG##

$OctopusURL = ""
$Octopusapikey = ""

$LicenseLevel = "" #Accepted values are  "Team","Professional","Enterprise"

##PROCESS##
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$Projects = ((Invoke-WebRequest $OctopusURL/api/projects/all -Headers $header).content | ConvertFrom-Json).count
$Users = ((Invoke-WebRequest $OctopusURL/api/users/all -Headers $header).content | ConvertFrom-Json).count
$Machines = ((Invoke-WebRequest $OctopusURL/api/Machines/all -Headers $header).content | ConvertFrom-Json).count

$remaining = 0
$limit = 0

switch ($LicenseLevel)
{
    'Professional' {
        $limit = 60
        $remaining = $limit - $Projects - $Users - $Machines
    }
    'Team' {
        $limit = 180
        $remaining = $limit - $Projects - $Users - $Machines        
    }
    'Enterprise' {
    }
    Default {Write-error "Unvalid value passed to `$LicenseLevel. Accepted values are 'Professional','Team','Enterprise'"}
}

Write-output "--Current status--"
Write-Output "Projects: $Projects"
Write-Output "Users: $Users"
Write-Output "Machines: $Machines"

If($LicenseLevel -eq "Enterprise"){
    Write-Output "Limit by license: Unlimited"
    Write-Output "Available 'Resources': Unlimited"
}
else{
    Write-Output "Limit by license: $limit"
    Write-Output "Available 'Resources': $remaining"
}

Write-Output "What are these Resource? Please read: https://github.com/OctopusDeploy/Issues/issues/1937"
