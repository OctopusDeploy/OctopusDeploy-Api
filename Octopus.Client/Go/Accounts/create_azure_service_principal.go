package main

import (
	"github.com/OctopusDeploy/go-octopusdeploy/client"
	"github.com/OctopusDeploy/go-octopusdeploy/enum"
	"github.com/OctopusDeploy/go-octopusdeploy/model"
	uuid "github.com/google/uuid"
)

var (
	octopusURL    string = "https://youroctourl"
	octopusAPIKey string = "API-YOURAPIKEY"

	// Azure specific details
	azureSubscriptionID uuid.UUID      = uuid.MustParse("Subscription UUID")
	azureApplicationID  uuid.UUID      = uuid.MustParse("Client UUID")
	azureTenantID       uuid.UUID      = uuid.MustParse("Tenant UUID")
	azureSecret         SensitiveValue = model.NewSensitiveValue("Secret")

	// Octopus Account details
	spaceName           string                      = "default"
	accountName         string                      = "Azure Account"
	accountDescription  string                      = "My Azure Account"
	tenantParticipation enum.TenantedDeploymentMode = enum.Untenanted
	tenantTags          []string                    = nil
	tenantIDs           []string                    = nil
	environmentIDs      []string                    = nil
)

func main() {
	client, err := client.NewClient(nil, octopusURL, octopusAPIKey, spaceName)

	if err != nil {
		// TODO: handle error
	}

	azureAccount, err := model.NewAzureServicePrincipalAccount(accountName, azureSubscriptionID, azureTenantID, azureApplicationID, azureSecret)

	if err != nil {
		// TODO: handle error
	}

	// Fill in account details
	azureAccount.Description = accountDescription
	azureAccount.TenantedDeploymentParticipation = tenantParticipation
	azureAccount.TenantTags = tenantTags
	azureAccount.TenantIDs = tenantIDs
	azureAccount.EnvironmentIDs = environmentIDs

	// Create account
	createdAccount, err := client.Accounts.Create(azureAccount)

	if err != nil {
		// TODO: handle error
	}
}
