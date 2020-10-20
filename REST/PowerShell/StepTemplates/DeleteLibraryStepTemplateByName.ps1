##CONFIG##
$OctopusAPIkey = "" #Octopus API Key
$OctopusURL = "" #Octopus URL
$TemplateName = "" #Template to delete

##PROCESS##
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$alltemplates = (Invoke-WebRequest $OctopusURL/api/actiontemplates/all -Method Get -Headers $header).content | ConvertFrom-Json

$TemplateToDelete = $alltemplates | ?{$_.Name -eq $TemplateName}

If(!([string]::IsNullOrEmpty($TemplateToDelete))){
    Invoke-WebRequest ($OctopusURL + $TemplateToDelete.links.self) -Method Delete -Headers $header
}
else{
    Write-Output "No step template found with the name: $TemplateName"
}
