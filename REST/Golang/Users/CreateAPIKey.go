package main

import (
	"log"

	"net/url"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

func main() {

	apiURL, err := url.Parse("https://YourUrl")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"
	userName := "MyUser"
	purpose := "Descriptive purpose"

	// Create client object
	client := octopusAuth(apiURL, APIKey, "")

	// Get user
	user := GetUser(client, userName)
	userApiKey := octopusdeploy.NewAPIKey(purpose, user.ID)

	userApiKey, err = client.APIKeys.Create(userApiKey)

}

func octopusAuth(octopusURL *url.URL, APIKey, space string) *octopusdeploy.Client {
	client, err := octopusdeploy.NewClient(nil, octopusURL, APIKey, space)
	if err != nil {
		log.Println(err)
	}

	return client
}

func GetUser(client *octopusdeploy.Client, OctopusUserName string) *octopusdeploy.User {

	// Get user account
	userQuery := octopusdeploy.UsersQuery{
		Filter: OctopusUserName,
	}

	userAccounts, err := client.Users.Get(userQuery)

	if err != nil {
		log.Println(err)
	}

	for i := 0; i < len(userAccounts.Items); i++ {
		// Check to see if it's a match
		if userAccounts.Items[i].Username == OctopusUserName {
			return userAccounts.Items[i]
		}
	}

	return nil
}