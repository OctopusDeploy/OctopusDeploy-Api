# Introduction
Utility.ps1 abstracts away the common start up needs of some scripts

## Current implementations:
- Octo Client
  - Checks \ReferenceLibrary for nuget package and if needed installs you're specified version based on static variables
- Octo Posh
  - Checks \ReferenceLibrary for nuget package and if needed installs for you
- Retrieves OctoDeploy API Key
  - Assumes User profile and if needed prompts user for API Key and then stores on User profile
- Working Directory
  - Based on a static variable, creates a working directory if not exists

### Example
See \Users\AddUser.ps1 for usage example but basically just dot source this in your script and then construct the class.

. '.\PowerShell\Helpers\octo-utility.ps1';

$repository = [utility]::new().get_octopus_repository();

#### Disclaimer
**You must assign the static variables based on your needs.**
