# Introduction
Utility.ps1 abstracts away the common start up needs of some scripts.

## Current implementations:
- Verify Octo Client
  - Checks \ReferenceLibrary for nuget package and if needed installs you're specified version based on static variables
- Retrieves OctoDeploy API Key
  - Assumes User profile and if needed prompts user for API Key and then stores on User profile

### Example
See \Users\AddUser.ps1 for usage example but basically just dot source this in your script and then construct the class.
