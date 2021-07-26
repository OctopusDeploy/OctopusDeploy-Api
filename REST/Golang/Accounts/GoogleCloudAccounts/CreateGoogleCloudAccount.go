package main

import (
	"encoding/base64"
	"fmt"
	"io/ioutil"
	"log"
	"net/url"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

func main() {

	apiURL, err := url.Parse("https://YourURL")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourURL"
	spaceName := "MySpace"
	googleAccountName := "MyGoogleAccount"
	pathToFile := "path:\\to\\google\\json\\file.json"

	// Get space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Read json file
	jsonRawData, err := ioutil.ReadFile(pathToFile)

	if err != nil {
		log.Println(err)
	}

	// Convert data to base 64 string
	jsonString := base64.StdEncoding.EncodeToString(jsonRawData)

	// Create sensitive variable
	octopusAccountString := octopusdeploy.SensitiveValue{
		HasValue: true,
		NewValue: &jsonString,
	}

	// Create google account
	googleAccount, err := octopusdeploy.NewGoogleCloudAccount(googleAccountName, &octopusAccountString)

	if err != nil {
		log.Println(err)
	}

	client.Accounts.Add(googleAccount)
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

	// Get specific space object
	space, err := client.Spaces.GetByName(spaceName)

	if err != nil {
		log.Println(err)
	} else {
		fmt.Println("Retrieved space " + space.Name)
	}

	return space
}