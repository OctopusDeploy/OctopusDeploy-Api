##CONFIG##
$OctopusAPIkey = "" #Octopus API Key
$OctopusURL = "" #Octopus URL
$ProjectName = "" #Project to delete

##PROCESS##
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$allprojects = (Invoke-WebRequest $OctopusURL/api/projects/all -Method Get -Headers $header).content | ConvertFrom-Json

$ProjectToDelete = $allprojects | ?{$_.Name -eq $ProjectName}

If(!([string]::IsNullOrEmpty($ProjectToDelete))){
    Invoke-WebRequest ($OctopusURL + $ProjectToDelete.links.self) -Method Delete -Headers $header
}
else{
    Write-Output "No project found with the name: $ProjectName"
}


