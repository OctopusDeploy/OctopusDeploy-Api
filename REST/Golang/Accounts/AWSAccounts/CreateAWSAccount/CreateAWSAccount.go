package main

import (
	"fmt"
	"log"
	"net/url"
	"os"

	"syscall"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
	"golang.org/x/term"
)

func main() {
	octopusURL := os.Args[1]
	spaceId := os.Args[2]
	name := os.Args[3]
	accessKey := os.Args[4]
	apiUrl, err := url.Parse(octopusURL)

	if err != nil {
		log.Println(err)
	}

	// Pass in the API key securely
	fmt.Println("Enter API Key Securely: ")
	apiKey, err := term.ReadPassword(int(syscall.Stdin))

	if err != nil {
		log.Println(err)
	}

	APIKey := string(apiKey)

	// Pass in the Azure Client password/secret securely
	fmt.Println("Enter AWS Secret Key Securely: ")
	clientPassword, err := term.ReadPassword(int(syscall.Stdin))

	if err != nil {
		log.Println(err)
	}
	password := string(clientPassword)
	awsSecretKey := octopusdeploy.NewSensitiveValue(password)

	// Call both functions from the main function
	octopusAuth(apiUrl, APIKey, spaceId)
	CreateAWSAccount(apiUrl, APIKey, spaceId, name, accessKey, awsSecretKey)
}

func octopusAuth(octopusURL *url.URL, APIKey, spaceId string) *octopusdeploy.Client {
	apiClient, err := octopusdeploy.NewClient(nil, octopusURL, APIKey, spaceId)

	if err != nil {
		log.Println(err)
	}

	return apiClient
}

func CreateAWSAccount(octopusURL *url.URL, APIKey string, spaceId string, name string, accessKey string, awsSecretKey *octopusdeploy.SensitiveValue) *octopusdeploy.AmazonWebServicesAccount {
	apiClient := octopusAuth(octopusURL, APIKey, spaceId)
	Account, err := octopusdeploy.NewAmazonWebServicesAccount(name, accessKey, awsSecretKey)

	if err != nil {
		log.Println(err)
	}

	apiClient.Accounts.Add(Account)

	return Account
}
```
```powershell PowerShell (REST API)
function Get-OctopusItems
{
	# Define parameters
    param(
    	$OctopusUri,
        $ApiKey,
        $SkipCount = 0
    )
    
    # Define working variables
    $items = @()
    $headers = @{"X-Octopus-ApiKey"="$ApiKey"}
    
    # Get intial set
    $resultSet = Invoke-RestMethod -Uri "$($OctopusUri)?skip=$SkipCount" -Method GET -Headers $headers

    # Store call results
    $items += $resultSet.Items
    
    # Check to see if resultset is bigger than page amount
    if (($resultSet.Items.Count -gt 0) -and ($resultSet.Items.Count -eq $resultSet.ItemsPerPage))
    {
        # Increment skip count
        $SkipCount += $resultSet.ItemsPerPage

        # Recurse
        $items += Get-OctopusItems -OctopusUri $OctopusUri -ApiKey $ApiKey -SkipCount $SkipCount
    }

    # Return results
    return $items
}

$apikey = 'API-YOURAPIKEY' # Get this from your profile
$OctopusUrl = 'https://youroctourl' # Your Octopus Server address
$spaceName = "default"
$spaceId = ""

# Create headers for API calls
$headers = @{"X-Octopus-ApiKey"="$ApiKey"}

# Get AWS credential values
$awsAccessKey = "YourAccessKey"
$awsSecretKey = "YourSecretKey"

# Octopus Account details
$accountName = "AWSAccount"
$accountDescription = "My AWS Account"
$accountTenantParticipation = "Untenanted"
$accountTenantTags = @()
$accountTenantIds = @()
$accountEnvironmentIds = @()

# Create json payload
$jsonPayload = @{
    AccountType = "AmazonWebServicesAccount"
    AccessKey = $awsAccessKey
    SecretKey = @{
        HasValue = $true
        NewValue = $awsSecretKey
    }
    Name = $accountName
    Description = $accountDescription
    TenantedDeploymentparticipation = $accountTenantParticipation
    TenantTags = $accountTenantTags
    TenantIds = $accountTenantIds
    EnvironmentIds = $accountEnvironmentIds
}

# Get space id
if ([string]::IsNullOrWhiteSpace($spaceName))
{
    $spaceId = "Spaces-1"
}
else
{
    # Get spaces
    $spaceId = (Get-OctopusItems -OctopusUri "$OctopusUrl/api/spaces" -ApiKey $apiKey | Where-Object {$_.Name -eq $spaceName})
}

# Call API to create account
Invoke-RestMethod -Method Post -Uri "$OctopusUrl/api/$spaceId/accounts" -Body ($jsonPayload | ConvertTo-Json -Depth 10) -Headers $headers
```
```powershell PowerShell (Octopus.Client)
# Load assembly
Add-Type -Path 'C:\Octopus.Client\Octopus.Client.dll'
$octopusURL = "https://youroctourl"
$octopusAPIKey = "API-YOURAPIKEY"

# AWS Credentials
$awsAccessKey = "AWSAccessKey"
$awsSecretKey = "AWSSecretKey"

# Octopus Account details
$accountName = "AWS Account"
$accountDescription = "My AWS Account"
$accountTenantParticipation = "Untenanted"
$accountTenantTags = @()
$accountTenantIds = @()
$accountEnvironmentIds = @()
$spaceName = "default"


$endpoint = New-Object Octopus.Client.OctopusServerEndpoint($octopusURL, $octopusAPIKey)
$repository = New-Object Octopus.Client.OctopusRepository($endpoint)
$client = New-Object Octopus.Client.OctopusClient($endpoint)

try
{
    # Get space
    $space = $repository.Spaces.FindByName($spaceName)
    $repositoryForSpace = $client.ForSpace($space)

    # Create aws account object
    $awsAccount = New-Object Octopus.Client.Model.Accounts.AmazonWebServicesAccountResource
    $awsAccount.AccessKey = $awsAccessKey
    $awsAccount.SecretKey = $awsSecretKey
    $awsAccount.Description = $accountDescription
    $awsAccount.Name = $accountName
    $awsAccount.TenantedDeploymentParticipation = [Octopus.Client.Model.TenantedDeploymentMode]::$accountTenantParticipation
    $awsAccount.TenantTags = New-Object Octopus.Client.Model.ReferenceCollection $accountTenantTags
    $awsAccount.TenantIds = New-Object Octopus.Client.Model.ReferenceCollection $accountTenantIds
    $awsAccount.EnvironmentIds = New-Object Octopus.Client.Model.ReferenceCollection $accountEnvironmentIds

    # Create account
    $repositoryForSpace.Accounts.Create($awsAccount)
}
catch
{
    Write-Host $_.Exception.Message
}
```
```csharp C#
// If using .net Core, be sure to add the NuGet package of System.Security.Permissions
#r "path\to\Octopus.Client.dll"

using Octopus.Client;
using Octopus.Client.Model;

var OctopusURL = "https://youroctourl";
var OctopusAPIKey = "API-YOURAPIKEY";

// Azure specific details
string awsAccessKey = "AWS Access Key";
string awsSecretKey = "AWS Secret Key";

// Octopus Account details
string octopusAccountName = "AWS Account";
string octopusAccountDescription = "My AWS Account";
Octopus.Client.Model.TenantedDeploymentMode octopusAccountTenantParticipation = Octopus.Client.Model.TenantedDeploymentMode.Untenanted;
Octopus.Client.Model.ReferenceCollection octopusAccountTenantTags = null;
Octopus.Client.Model.ReferenceCollection octopusAccountTenantIds = null;
Octopus.Client.Model.ReferenceCollection octopusAccountEnvironmentIds = null;
string spaceName = "default";

var endpoint = new OctopusServerEndpoint(OctopusURL, OctopusAPIKey);
var repository = new OctopusRepository(endpoint);
var client = new OctopusClient(endpoint);
var awsAccount = new Octopus.Client.Model.Accounts.AmazonWebServicesAccountResource();

try
{
	// Get space
	var space = repository.Spaces.FindByName(spaceName);
	var repositoryForSpace = client.ForSpace(space);

	// Fill in account details
	awsAccount.AccessKey = awsAccessKey;
	awsAccount.SecretKey = awsSecretKey;
	awsAccount.Name = octopusAccountName;
	awsAccount.Description = octopusAccountDescription;
	awsAccount.TenantedDeploymentParticipation = octopusAccountTenantParticipation;
	awsAccount.TenantTags = octopusAccountTenantTags;
	awsAccount.TenantIds = octopusAccountTenantIds;
	awsAccount.EnvironmentIds = octopusAccountEnvironmentIds;

	// Create account
	repositoryForSpace.Accounts.Create(awsAccount);
}
catch (Exception ex)
{
	Console.WriteLine(ex.Message);
	return;
}
```
```python Python3

import json
import requests

octopus_server_uri = 'https://your.octopus.app/api'
octopus_api_key = 'API-YOURAPIKEY'
headers = {'X-Octopus-ApiKey': octopus_api_key}

space_name = 'Default'

account = {
    'Id': None,
    'AccountType': 'AmazonWebServicesAccount',
    'AccessKey': 'AWS Access Key',
    'SecretKey': {
        'HasValue': True,
        'NewValue': 'AWS Secret Key' # replace with valid secret
    },
    'ActiveDirectoryEndpointBaseUri': '',
    'ResourceManagementEndpointBaseUri': '',
    'Name': 'AWS Account', # replace with preferred name
    'Description': 'My AWS Account', # replace with preferred description
    'TenantedDeploymentParticipation': 'Untenanted',
    'TenantTags': [],
    'TenantIds': [],
    'EnvironmentIds': []
}

uri = '{0}/spaces/all'.format(octopus_server_uri)
response = requests.get(uri, headers=headers)
response.raise_for_status()

spaces = json.loads(response.content.decode('utf-8'))
space = next((x for x in spaces if x['Name'] == space_name), None)

uri = '{0}/{1}/accounts'.format(octopus_server_uri, space['Id'])
response = requests.post(uri, headers=headers, json=account)
response.raise_for_status()
```
```go Go
package main

import (
	"fmt"
	"log"

	"net/url"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

func main() {

	apiURL, err := url.Parse("https://YourURL")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"
	awsAccountName := "MyAWSAccount"
	awsAccessKey := "MyAccessKey"
	awsSecretKey := "MySecretKey"
	awsSecretKeySensitive := octopusdeploy.SensitiveValue{
		HasValue: true,
		NewValue: &awsSecretKey,
	}
	spaceName := "Default"

	// Get space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Create AWS account object
	awsAccount, err := octopusdeploy.NewAmazonWebServicesAccount(awsAccountName, awsAccessKey, &awsSecretKeySensitive)

	if err != nil {
		log.Println(err)
	}
	
	client.Accounts.Add(awsAccount)
}

func octopusAuth(octopusURL *url.URL, APIKey, space string) *octopusdeploy.Client {
	client, err := octopusdeploy.NewClient(nil, octopusURL, APIKey, space)
	if err != nil {
		log.Println(err)
	}

	return client
}

func GetSpace(octopusURL *url.URL, APIKey string, spaceName string) *octopusdeploy.Space {
	client := octopusAuth(octopusURL, APIKey, "")

	// Get specific space object
	space, err := client.Spaces.GetByName(spaceName)

	if err != nil {
		log.Println(err)
	} else {
		fmt.Println("Retrieved space " + space.Name)
	}

	return space
}