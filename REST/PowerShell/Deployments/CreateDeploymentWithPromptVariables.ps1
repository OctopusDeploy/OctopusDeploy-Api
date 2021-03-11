##CONFIG##
$apiKey = "Your API Key"
$OctopusURL = "Your Octopus URL"

$ProjectName = "Your Project Name"
$EnvironmentName = "Your Environment Name"
$ReleaseNumber = "Your Release Number"
$spaceName = "Your Space Name"
$promptedVariableValue = "VariableName::Variable Value"

##PROCESS##
$Header =  @{ "X-Octopus-ApiKey" = $apiKey }

$spaceList = Invoke-RestMethod "$OctopusUrl/api/spaces?partialName=$([System.Web.HTTPUtility]::UrlEncode($spaceName))&skip=0&take=1" -Headers $Header
$spaceId = $spaceList.Items[0].Id

$ProjectList = Invoke-RestMethod "$OctopusURL/api/$spaceId/projects?name=$([System.Web.HTTPUtility]::UrlEncode($projectName))&skip=0&take=1" -Headers $header
$ProjectId = $ProjectList.Items[0].Id

$EnvironmentList = Invoke-RestMethod -Uri "$OctopusURL/api/$spaceId/Environments?name=$([System.Web.HTTPUtility]::UrlEncode($EnvironmentName))&skip=0&take=1" -Headers $Header
$EnvironmentId = $EnvironmentList.Items[0].Id

$ReleaseList = Invoke-RestMethod -Uri "$OctopusURL/api/$spaceId/projects/$ProjectId/releases?searchByVersion=$([System.Web.HTTPUtility]::UrlEncode($releaseNumber))&skip=0&take=1" -Headers $Header
$ReleaseId = $ReleaseList.Items[0].Id

$deploymentPreview = Invoke-RestMethod "$OctopusUrl/api/$spaceId/releases/$releaseId/deployments/preview/$($EnvironmentId)?includeDisabledSteps=true" -Headers $Header

$deploymentFormValues = @{}
$promptedValueList = @(($promptedVariableValue -Split "`n").Trim())
   
foreach($element in $deploymentPreview.Form.Elements)
{
    $nameToSearchFor = $element.Control.Name
    $uniqueName = $element.Name
    $isRequired = $element.Control.Required
    
    $promptedVariablefound = $false
    
    Write-Host "Looking for the prompted variable value for $nameToSearchFor"
    foreach ($promptedValue in $promptedValueList)
    {
        $splitValue = $promptedValue -Split "::"
        Write-Host "Comparing $nameToSearchFor with provided prompted variable $($promptedValue[$nameToSearchFor])"
        if ($splitValue.Length -gt 1)
        {
            if ($nameToSearchFor -eq $splitValue[0])
            {
                Write-Host "Found the prompted variable value $nameToSearchFor"
                $deploymentFormValues[$uniqueName] = $splitValue[1]
                $promptedVariableFound = $true
                break
            }
        }
    }
    
    if ($promptedVariableFound -eq $false -and $isRequired -eq $true)
    {
        Write-Highlight "Unable to find a value for the required prompted variable $nameToSearchFor, exiting"
        Exit 1
    }
}

#Creating deployment and setting value to the only prompt variable I have on $p.Form.Elements. You're gonna have to do some digging if you have more variables
$DeploymentBody = @{ 
            ReleaseID = $releaseId #mandatory
            EnvironmentID = $EnvironmentId #mandatory
            FormValues = $deploymentFormValues
            ForcePackageDownload=$False
            ForcePackageRedeployment=$False
            UseGuidedFailure=$False
          } | ConvertTo-Json
          
Invoke-RestMethod -Uri "$OctopusURL/api/$spaceId/deployments" -Method Post -Headers $Header -Body $DeploymentBody
