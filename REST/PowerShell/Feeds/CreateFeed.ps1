$OctopusAPIkey = $env:OctopusAPIKey
$OctopusURL = $env:OctopusURL
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$body = @{
    FeedURI = "http://Packages.com/nuget"
    Name = "MyFeed"
    Password = @{NewValue = "MyPasswordInClearText"} #remove if feed doesn't have username/password
    Username = "Myusername" #remove if feed doesn't have username/password
} | ConvertTo-Json

<#
Raw JSON body looks like this:

{
    "Username":  "MyUsername",
    "Name":  "MyFeed",
    "Password":  {
                     "NewValue":  "MyPasswordInClearText"
                 },
    "FeedURI":  "http://Packages.com/nuget"
}

#>

Invoke-WebRequest "$OctopusURL/api/feeds" -Headers $header -Body $body -Method Post