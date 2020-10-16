package main

import (
	"fmt"
	"log"
	"os"

	"github.com/OctopusDeploy/go-octopusdeploy/client"
	"github.com/OctopusDeploy/go-octopusdeploy/model"
	"golang.org/x/crypto/ssh/terminal"
)

func main() {
	octopusURL := os.Args[1]
	space := os.Args[2]
	name := os.Args[3]
	accessKey := os.Args[4]

	// Pass in the API key securely
	fmt.Println("Enter Password Securely: ")
	apiKey, err := terminal.ReadPassword(0)

	if err != nil {
		log.Println(err)
	}

	APIKey := string(apiKey)

	// Pass in the Azure Client password/secret securely
	fmt.Println("Enter AWS Secret Key Securely: ")
	clientPassword, err := terminal.ReadPassword(0)

	if err != nil {
		log.Println(err)
	}
	password := string(clientPassword)
	awsSecretKey := model.NewSensitiveValue(password)

	// Call both functions from the main function
	octopusAuth(octopusURL, APIKey, space)
	CreateAWSAccount(octopusURL, APIKey, space, name, accessKey, awsSecretKey)
}

func octopusAuth(octopusURL, APIKey, space string) *client.Client {
	apiClient, err := client.NewClient(nil, octopusURL, APIKey, space)
	if err != nil {
		log.Println(err)
	}

	return apiClient
}

func CreateAWSAccount(octopusURL string, APIKey string, space string, name string, accessKey string, awsSecretKey model.SensitiveValue) *model.Account {
	apiClient := octopusAuth(octopusURL, APIKey, space)
	Account, err := model.NewAwsServicePrincipalAccount(name, accessKey, awsSecretKey)

	if err != nil {
		log.Println(err)
	}

	apiClient.Accounts.Add(Account)

	return Account
}
