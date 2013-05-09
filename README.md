## Octopus Deploy 2.0 API Documentation

[Octopus Deploy](http://octopusdeploy.com/) is a user-friendly automated deployment tool for .NET developers. This GitHub repository exists to provide documentation for the upcoming **Octopus Deploy 2.0** HTTP API. 

For Octopus Deploy 2.0, we're making a lot of changes and improvements to the API, and our goal is to make the Octopus user interface API driven. When we first built the API for Octopus Deploy, it didn't come with documentation. The goal of this GitHub repository is to document the API from the start. 

**To be clear, this is documentation for an upcoming, unreleased version of the API. While many of the concepts in this documentation also apply to the current API, some parts won't.**

### Jumping in

The Octopus Deploy API is available at:

    http://<your-octopus-installation>/api

You'll need an API key to access the API. You can get your API key from your profile page on the Octopus web portal. This should be sent in the `X-Octopus-ApiKey` HTTP header, or in an `apikey` query string parameter. 

### Concepts

1. Authentication 
2. Links
3. Resources
   1. Environments
   2. Projects
   3. Project groups
   4. Steps
   5. Variables
   6. Releases
   7. Deployments
   8. Tasks
   9. Feeds
   10. Events
   11. Groups
   12. Users
   13. Permissions
