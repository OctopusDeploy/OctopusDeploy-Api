package main

import (
	"fmt"
	"log"
	"github.com/google/uuid"
	"net/url"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

func main() {

	apiURL, err := url.Parse("https://YourURL")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"
	accountName := "MyAzureAccount"
	subscriptionID := "MySubscriptionId"
	tenantID := "MyTenantId"
	applicationID := "MyApplicationId"
	password := "MyPassword"
	azureClientPassword := octopusdeploy.SensitiveValue{
		HasValue: true,
		NewValue: &password,
	}
	spaceName := "Default"

	// Get space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Convert values
	subscriptionID_UUID, _ := uuid.Parse(subscriptionID)
	tenantID_UUID, _ := uuid.Parse(tenantID)
	applicationID_UUID, _ := uuid.Parse(applicationID)

	// Create AWS account object
	azureAccount, err := octopusdeploy.NewAzureServicePrincipalAccount(accountName, subscriptionID_UUID, tenantID_UUID, applicationID_UUID, &azureClientPassword)

	if err != nil {
		log.Println(err)
	}

	client.Accounts.Add(azureAccount)
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