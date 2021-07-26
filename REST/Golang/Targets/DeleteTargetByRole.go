package main

import (
	"fmt"
	"log"
	"net/url"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

func main() {

	apiURL, err := url.Parse("https://YourURL")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"
	spaceName := "Default"
	roleName := "MyRole"

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client object
	client := octopusAuth(apiURL, APIKey, space.ID)

	machines := GetMachinesWithRole(client, roleName)

	for i := 0; i < len(machines); i++ {
		// Delete machine
		fmt.Println("Deleting " + machines[i].Name)
		client.Machines.DeleteByID(machines[i].ID)
	}
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

func GetMachinesWithRole(client *octopusdeploy.Client, roleName string) []*octopusdeploy.DeploymentTarget {
	// Get machines
	machines, err := client.Machines.GetAll()

	// New variable for machines
	machinesWithRole := []*octopusdeploy.DeploymentTarget{}

	if err != nil {
		log.Println(err)
	}

	for i := 0; i < len(machines); i++ {
		if contains(machines[i].Roles, roleName) {
			machinesWithRole = append(machinesWithRole, machines[i])
		}
	}

	return machinesWithRole
}

func contains(s []string, str string) bool {
	for _, v := range s {
		if v == str {
			return true
		}
	}

	return false
}