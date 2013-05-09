## Authentication

You authenticate with the Octopus Deploy API by providing an API key. You'll find your API key in the Octopus web portal, by clicking on your profile:

![First, click on My Profile under your username](http://res.cloudinary.com/octopusdeploy/image/upload/v1366768866/2013_04_24_11_59_11_Dashboard_Octopus_ps9dhi.png)

And scrolling to the bottom:

![Then, scroll to the bottom to see your username](http://res.cloudinary.com/octopusdeploy/image/upload/v1366768867/2013_04_24_11_59_34_Configuration_Octopus_famfmz.png)

Once you have an API key, you can provide it to the API in the following ways:

 1. Through the `X-Octopus-ApiKey` HTTP header with all requests (preferred)
 2. Through the `X-NuGet-ApiKey` HTTP header with all requests
 3. As an `apikey` query string parameter with all requests (should only be used for simple requests)

If you are using integrated Windows Authentication to host the Octopus web portal, you may also need to provide windows authentication credentials seperately. How you do this will depend on the client framework you are using; for .NET developers, it can be done by setting:

    request.Credentials = CredentialCache.DefaultNetworkCredentials;

