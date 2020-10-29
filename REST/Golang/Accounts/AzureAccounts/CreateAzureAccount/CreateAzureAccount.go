package main

import (
	"fmt"
	"log"
	"net/url"
	"os"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
	"github.com/google/uuid"
	"golang.org/x/crypto/ssh/terminal"
)

func main() {
	octopusURL, _ := url.Parse(os.Args[1])
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
	azureClientPassword := octopusdeploy.NewSensitiveValue(password)

	// Call both functions from the main function
	octopusAuth(octopusURL, APIKey, space)
	CreateAzureAccount(octopusURL, APIKey, space, name, subscriptionId, tenantID, applicationID, azureClientPassword)
}

func octopusAuth(octopusURL *url.URL, APIKey, space string) *octopusdeploy.Client {
	client, err := octopusdeploy.NewClient(nil, octopusURL, APIKey, space)
	if err != nil {
		log.Println(err)
	}

	return client
}

func CreateAzureAccount(octopusURL *url.URL, APIKey string, space string, name string, subscriptionID uuid.UUID, tenantID uuid.UUID, applicationID uuid.UUID, azureClientPassword *octopusdeploy.SensitiveValue) *octopusdeploy.AzureServicePrincipalAccount {
	client := octopusAuth(octopusURL, APIKey, space)
	Account, err := octopusdeploy.NewAzureServicePrincipalAccount(name, subscriptionID, tenantID, applicationID, azureClientPassword)

	if err != nil {
		log.Println(err)
	}

	client.Accounts.Add(Account)
	log.Printf("\nAccount %s: Created", name)

	return Account
}
