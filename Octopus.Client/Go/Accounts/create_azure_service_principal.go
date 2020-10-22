package main

import (
	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
	uuid "github.com/google/uuid"
)

var (
	octopusURL    string = "https://youroctourl"
	octopusAPIKey string = "API-YOURAPIKEY"

	// Azure specific details
	azureSubscriptionID uuid.UUID      = uuid.MustParse("Subscription-Guid")
	azureApplicationID  uuid.UUID      = uuid.MustParse("Client-Guid")
	azureTenantID       uuid.UUID      = uuid.MustParse("Tenant-Guid")
	azureSecret         SensitiveValue = model.NewSensitiveValue("Secret")

	// Octopus Account details
	accountName         string   = "Azure Account"
	accountDescription  string   = "My Azure Account"
	tenantParticipation string   = "Untenanted"
	tenantTags          []string = nil
	tenantIDs           []string = nil
	environmentIDs      []string = nil
	spaceName           string   = "default"
)

func main() {
	client, err := octopusdeploy.NewClient(nil, octopusURL, octopusAPIKey, spaceName)
	if err != nil {
		// TODO: handle error
	}

	azureAccount, err := octopusdeploy.NewAzureServicePrincipalAccount(accountName, azureSubscriptionID, azureTenantID, azureApplicationID, azureSecret)
	if err != nil {
		// TODO: handle error
	}

	// fill in account details
	azureAccount.Description = accountDescription
	azureAccount.TenantedDeploymentParticipation = tenantParticipation
	azureAccount.TenantTags = tenantTags
	azureAccount.TenantIDs = tenantIDs
	azureAccount.EnvironmentIDs = environmentIDs

	// create account
	createdAccount, err := client.Accounts.Add(azureAccount)
	if err != nil {
		// TODO: handle error
	}
}
