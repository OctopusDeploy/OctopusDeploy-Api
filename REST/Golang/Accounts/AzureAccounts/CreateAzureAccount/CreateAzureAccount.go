package main

import (
	"fmt"
	"github.com/OctopusDeploy/go-octopusdeploy/client"
	"github.com/OctopusDeploy/go-octopusdeploy/model"
	"github.com/google/uuid"
	"golang.org/x/crypto/ssh/terminal"
	"log"
	"os"
)

func main() {
	octopusURL := os.Args[1]
	space := os.Args[2]
	name := os.Args[3]
	subscriptionId, _ := uuid.Parse(os.Args[4])
	tenantID, _ := uuid.Parse(os.Args[5])
	applicationID, _ := uuid.Parse(os.Args[6])

	// Pass in the API key securely
	fmt.Println("Enter Password Securely: ")
	apiKey, err := terminal.ReadPassword(0)

	if err != nil {
		log.Println(err)
	}

	APIKey := string(apiKey)

	// Pass in the Azure Client password/secret securely
	fmt.Println("Enter Azure Client ID Password Securely: ")
	clientPassword, err := terminal.ReadPassword(0)

	if err != nil {
		log.Println(err)
	}
	password := string(clientPassword)
	azureClientPassword := model.NewSensitiveValue(password)

	// Call both functions from the main function
	octopusAuth(octopusURL, APIKey, space)
	CreateAzureAccount(octopusURL, APIKey, space, name, subscriptionId, tenantID, applicationID, azureClientPassword)
}

func octopusAuth(octopusURL, APIKey, space string) *client.Client {
	client, err := client.NewClient(nil, octopusURL, APIKey, space)
	if err != nil {
		log.Println(err)
	}

	return client
}

func CreateAzureAccount(octopusURL string, APIKey string, space string, name string, subscriptionID uuid.UUID, tenantID uuid.UUID, applicationID uuid.UUID, azureClientPassword model.SensitiveValue) *model.Account {
	client := octopusAuth(octopusURL, APIKey, space)
	Account, err := model.NewAzureServicePrincipalAccount(name, subscriptionID, tenantID, applicationID, azureClientPassword)

	if err != nil {
		log.Println(err)
	}

	client.Accounts.Add(Account)

	return Account
}
