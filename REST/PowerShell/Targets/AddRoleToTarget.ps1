# set up variables
$apikey = ""
$octopusURL = ""
$filter = "My Deployment Target"


# apply a new role to an existing machine
$machines = Invoke-RestMethod -uri ($octopusURL, "/api/machines/all?apikey=", $apikey -join "")
$machine = $machines | ? { $_.Name -eq $filter} 
$machine.roles += ("mynewrole")
$putTo = ($octopusURL, "/api/machines/", $machine.Id , "?apikey=", $apikey -join "")
$putresult = Invoke-RestMethod -uri $putTo -Method PUT -Body ($machine |convertto-json -depth 5)


# prove it's worked correctly
Write-Output $putresult