package main

import (
	"fmt"
	"log"
	"net/url"
	"os"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
	"golang.org/x/crypto/ssh/terminal"
)

func main() {
	octopusURL, _ := url.Parse(os.Args[1])
	space := os.Args[2]
	name := os.Args[3]
	accessKey := os.Args[4]

	// Pass in the API key securely
	fmt.Println("Enter API Key Securely: ")
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
	awsSecretKey := octopusdeploy.NewSensitiveValue(password)

	// Call both functions from the main function
	octopusAuth(octopusURL, APIKey, space)
	CreateAWSAccount(octopusURL, APIKey, space, name, accessKey, awsSecretKey)
}

func octopusAuth(octopusURL *url.URL, APIKey string, space string) *octopusdeploy.Client {
	apiClient, err := octopusdeploy.NewClient(nil, octopusURL, APIKey, space)
	if err != nil {
		log.Println(err)
	}

	return apiClient
}

func CreateAWSAccount(octopusURL *url.URL, APIKey string, space string, name string, accessKey string, awsSecretKey *octopusdeploy.SensitiveValue) *octopusdeploy.AmazonWebServicesAccount {
	apiClient := octopusAuth(octopusURL, APIKey, space)
	Account, err := octopusdeploy.NewAmazonWebServicesAccount(name, accessKey, awsSecretKey)

	if err != nil {
		log.Println(err)
	}

	apiClient.Accounts.Add(Account)
	log.Printf("\nAccount %s: Created", name)

	return Account
}
