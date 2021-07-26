package main

import (
	"fmt"
	"log"
	"net/url"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
	//"strconv.Itoa"
)

func main() {

	apiURL, err := url.Parse("https://YourURL")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"
	spaceName := "Default"
	machineName := "MyMachine"

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client object
	client := octopusAuth(apiURL, APIKey, space.ID)

	machine := GetMachine(client, machineName)

	if nil != machine {
		// Delete machine
		fmt.Println("Deleting " + machine.Name)
		client.Machines.DeleteByID(machine.ID)
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

func GetMachine(client *octopusdeploy.Client, machineName string) *octopusdeploy.DeploymentTarget {
	// Get machines
	machines, err := client.Machines.GetByName(machineName)

	if err != nil {
		log.Println(err)
	}

	for i := 0; i < len(machines); i++ {
		if machines[i].Name == machineName {
			return machines[i]
		}
	}

	return nil
}