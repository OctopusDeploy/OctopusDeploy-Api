$OctopusAPIkey = "" #Your Octopus API Key
$OctopusURL = "" #Your Octopus base url
$header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

$feedID = "" #ID of the feed you want to modify. The best way to get this ID is by going to Library -> External feeds -> [Edit] on the feed you want to delete -> Check the ID

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

Invoke-WebRequest "$OctopusURL/api/feeds/$feedID" -Headers $header -Body $body -Method PUT