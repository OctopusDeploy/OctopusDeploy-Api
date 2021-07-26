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
	machine := GetMachine(apiURL, APIKey, space, machineName)

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

	// Get specific space object
	space, err := client.Spaces.GetByName(spaceName)

	if err != nil {
		log.Println(err)
	} else {
		fmt.Println("Retrieved space " + space.Name)
	}

	return space
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

func GetMachine(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, MachineName string) *octopusdeploy.DeploymentTarget {
	// Create client
	client := octopusAuth(octopusURL, APIKey, space.ID)

	// Get target
	deploymentTargets, err := client.Machines.GetByName(MachineName)

	if err != nil {
		log.Println(err)
	}

	// Loop through returned targets
	for i := 0; i < len(deploymentTargets); i++ {
		if deploymentTargets[i].Name == MachineName {
			return deploymentTargets[i]
		}
	}

	return nil
}