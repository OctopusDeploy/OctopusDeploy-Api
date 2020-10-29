package main

import (
	"fmt"
	"log"
	"os"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
	"golang.org/x/crypto/ssh/terminal"
)

func main() {
	octopusURL := os.Args[1]
	space := os.Args[2]
	name := os.Args[3]

	// Pass in the API key securely
	fmt.Println("Enter Password Securely: ")
	apiKey, err := terminal.ReadPassword(0)

	if err != nil {
		log.Println(err)
	}

	APIKey := string(apiKey)

	// Call both functions from the main function
	octopusAuth(octopusURL, APIKey, space)
	CreateUsernamePasswordAccount(octopusURL, APIKey, space, name)
}

func octopusAuth(octopusURL, APIKey, space string) *octopusdeploy.Client {
	client := octopusdeploy.NewClient(nil, octopusURL, APIKey)

	return client
}

func CreateUsernamePasswordAccount(octopusURL string, APIKey string, space string, name string) *octopusdeploy.Account {
	client := octopusAuth(octopusURL, APIKey, space)
	Account := octopusdeploy.NewUsernamePasswordAccount(name)

	client.Account.Add(Account)

	return Account
}
