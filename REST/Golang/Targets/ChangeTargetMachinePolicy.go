package main

import (
	"fmt"
	"log"

	"net/url"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

func main() {

	apiURL, err := url.Parse("https://youroctourl")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"
	spaceName := "Default"
	newMachinePolicyName := "MyMachinePolicy"
	machineName := "MyMachine"

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Get machine policies
	newMachinePolicy := GetMachinePolicy(apiURL, APIKey, space, newMachinePolicyName)

	// Get machine reference
	machine := GetTarget(apiURL, APIKey, space, machineName)

	// Update
	machine.MachinePolicyID = newMachinePolicy.ID
	client := octopusAuth(apiURL, APIKey, space.ID)
	client.Machines.Update(machine)
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

	spaceQuery := octopusdeploy.SpacesQuery{
		Name: spaceName,
	}

	// Get specific space object
	spaces, err := client.Spaces.Get(spaceQuery)

	if err != nil {
		log.Println(err)
	}

	for _, space := range spaces.Items {
		if space.Name == spaceName {
			return space
		}
	}

	return nil
}

func GetMachinePolicy(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, MachinePolicyName string) *octopusdeploy.MachinePolicy {
	// Create client
	client := octopusAuth(octopusURL, APIKey, space.ID)

	// Get the machine policy
	machinePolicies, err := client.MachinePolicies.GetByPartialName(MachinePolicyName)

	if err != nil {
		log.Println(err)
	}

	for i := 0; i < len(machinePolicies); i++ {
		if machinePolicies[i].Name == MachinePolicyName {
			return machinePolicies[i]
		}
	}

	return nil
}

func GetTarget(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, targetName string) *octopusdeploy.DeploymentTarget {
	// Create client
	client := octopusAuth(octopusURL, APIKey, space.ID)

	machinesQuery := octopusdeploy.MachinesQuery{
		Name: targetName,
	}

	// Get specific machine object
	machines, err := client.Machines.Get(machinesQuery)

	if err != nil {
		log.Println(err)
	}

	for _, machine := range machines.Items {
		if machine.Name == targetName {
			return machine
		}
	}

	return nil
}