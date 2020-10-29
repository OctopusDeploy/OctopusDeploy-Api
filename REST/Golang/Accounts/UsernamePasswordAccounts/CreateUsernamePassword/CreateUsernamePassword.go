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

func octopusAuth(octopusURL *url.URL, APIKey, space string) *octopusdeploy.Client {
	client, err := octopusdeploy.NewClient(nil, octopusURL, APIKey, space)
	if err != nil {
		log.Println(err)
	}

	return client
}

func CreateUsernamePasswordAccount(octopusURL *url.URL, APIKey string, space string, name string) *octopusdeploy.UsernamePasswordAccount {
	client := octopusAuth(octopusURL, APIKey, space)
	Account, err := octopusdeploy.NewUsernamePasswordAccount(name)

	if err != nil {
		log.Println(err)
	}

	client.Accounts.Add(Account)

	return Account
}
