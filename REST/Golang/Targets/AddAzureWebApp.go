package main

import (
	"fmt"
	"log"

	"net/url"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

func main() {
	spaceName := "Default"
	azureServicePrincipalName := "MyAzurePrincipal"
	environmentNames := []string{"Development", "Production"}
	roles := []string{"MyRole"}
	azureWebAppName := "MyWebApp"
	azureResourceGroupName := "MyResourceGroup"

	apiURL, err := url.Parse("https://youroctourl")
	if err != nil {
		log.Println(err)
	}

	APIKey := "API-YOURKEY"

	// Get space to work with
	space := GetSpace(apiURL, APIKey, spaceName)

	// Get the azure account
	azureAccount := GetAzureAccount(apiURL, APIKey, space, azureServicePrincipalName)

	// Get client for space
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Create new Azure Web App object
	azureWebApp := octopusdeploy.NewAzureWebAppEndpoint()
	azureWebApp.CommunicationStyle = "AzureWebApp"
	azureWebApp.AccountID = azureAccount.ID
	azureWebApp.ResourceGroupName = azureResourceGroupName
	azureWebApp.WebAppName = azureWebAppName

	// Get deployment IDs
	environmentIds := []string{}
	for i := 0; i < len(environmentNames); i++ {
		environment := GetEnvironment(apiURL, APIKey, space, environmentNames[i])
		environmentIds = append(environmentIds, environment.ID)
	}

	// Create new deployment target object
	deploymentTarget := octopusdeploy.NewDeploymentTarget(azureWebAppName, azureWebApp, environmentIds, roles)

	machine, err := client.Machines.Add(deploymentTarget)

	if err != nil {
		log.Println(err)
	}

	fmt.Println("Successfully created " + machine.ID)
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

	spaceQuery := octopusdeploy.SpacesQuery{
		Name: spaceName,
	}

	// Get specific space object
	spaces, err := client.Spaces.Get(spaceQuery)

	if err != nil {
		log.Println(err)
	}

	for _, space := range spaces.Items {
		if space.Name == spaceName {
			return space
		}
	}

	return nil
}

func GetAzureAccount(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, accountName string) *octopusdeploy.AzureServicePrincipalAccount {
	// Get client for space
	client := octopusAuth(octopusURL, APIKey, space.ID)

	// Create accounts query
	accountsQuery := octopusdeploy.AccountsQuery{
		PartialName: accountName,
	}

	accounts, err := client.Accounts.Get(accountsQuery)

	if err != nil {
		log.Println(err)
	}

	// return the result, casting to specific account type
	return accounts.Items[0].(*octopusdeploy.AzureServicePrincipalAccount)
}

func GetEnvironment(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, environmentName string) *octopusdeploy.Environment {
	// Get client for space
	client := octopusAuth(octopusURL, APIKey, space.ID)

	// Get environment
	environmentsQuery := octopusdeploy.EnvironmentsQuery {
		Name: environmentName,		
	}
	environments, err := client.Environments.Get(environmentsQuery)
	if err != nil {
		log.Println(err)
	}

	// Loop through results
	for _, environment := range environments.Items {
		if environment.Name == environmentName {
			return environment
		}
	}

	return nil
}