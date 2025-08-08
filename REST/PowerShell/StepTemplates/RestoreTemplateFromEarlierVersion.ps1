# Restores a earlier version of a specific step template to an earlier version
# You can find previous step template versions (and version ids) at /api/Spaces-##/actiontemplates/ActionTemplates-##

# Define working variables
$ApiKey = "API-#####"
$OctopusServerUrl = "https://YOUR-OCTO-URL"
$SpaceId = "Spaces-##"
$myTemplateId = "ActionTemplates-##"
$versionToRestore = "#" # Set to the old version of the template you want restored

$headers = @{ "X-Octopus-ApiKey" = $ApiKey }

# Get the desired version of the template
$stepTemplate = (Invoke-RestMethod -Method Get -Uri "$OctopusServerUrl/api/$SpaceId/actiontemplates/$myTemplateId/versions/$versionToRestore" -Headers $headers)

# Put the old template back to restore it
Invoke-RestMethod -Method Put -Uri "$OctopusServerUrl/api/$SpaceId/actiontemplates/$myTemplateId" -Body ($stepTemplate | ConvertTo-Json -Depth 10) -Headers $headers
