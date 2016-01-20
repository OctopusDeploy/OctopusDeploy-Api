##CONFIGURATION##

$OctopusURI = "" #Octopus URL

$OctopusUsername = "" #API Key will belong to this user
$OctopusPassword = "" #Password of the user above

$APIKeyPurpose = "" #Brief text to describe the purpose of your API Key.


##PROCESS##


#Adding libraries. Make sure to modify these paths acording to your environment setup.
Add-Type -Path "C:\Tools\Newtonsoft.Json.dll"
Add-Type -Path "C:\Tools\Octopus.Client.dll"

#Creating a connection
$endpoint = new-object Octopus.Client.OctopusServerEndpoint $OctopusURI
$repository = new-object Octopus.Client.OctopusRepository $endpoint

#Creating login object
$LoginObj = New-Object Octopus.Client.Model.LoginCommand 
$LoginObj.Username = $OctopusUsername
$LoginObj.Password = $OctopusPassword

#Loging in to Octopus
$repository.Users.SignIn($LoginObj)

#Getting current user logged in
$UserObj = $repository.Users.GetCurrent()

#Creating API Key for user. This automatically gets saved to the database.
$ApiObj = $repository.Users.CreateApiKey($UserObj, $APIKeyPurpose)

#Returns the API Key in clear text
$ApiObj.ApiKey