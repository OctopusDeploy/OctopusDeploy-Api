$OctopusServerUrl = "https://"
$ApiKey = ""

#Plug in the desired values for your team here or substitute a JSON from an example creation that you would like to build from.
$json = '
{
	"Id": null,
	"Name": "TestCreate3",
	"SpaceId": "Spaces-1",
	"ExternalSecurityGroups": [],
	"MemberUserIds": [],
	"CanBeDeleted": true,
	"CanBeRenamed": true,
	"CanChangeMembers": true,
	"CanChangeRoles": true,
	"Links": null,
	"Description": ""
}
'
Invoke-RestMethod -Method "POST" "$OctopusServerUrl/api/teams" -Headers @{"X-Octopus-ApiKey" = $ApiKey } -body $json
