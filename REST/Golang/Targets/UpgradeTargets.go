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
	machineNames := []string{"MyMachine"}

	// Get the space object
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client for space
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Get machines
	machines := GetMachines(client, machineNames, environment)

	// Create new health check task
	upgradeTask := octopusdeploy.NewTask()
	upgradeTask.SpaceID = space.ID
	upgradeTask.Name = "Upgrade"
	upgradeTask.Description = "Upgrade target task from Go"

	// Add the arguments
	if len(machines) > 0 {
		machineIds := []string{}
		for _, entry := range machines {
			machineIds = append(machineIds, entry.ID)
		}

		upgradeTask.Arguments["MachineIds"] = machineIds
	}

	// Execute the task
	task, err := client.Tasks.Add(upgradeTask)

	fmt.Println(task)
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

func GetEnvironment(client *octopusdeploy.Client, environmentName string) *octopusdeploy.Environment {
	// Get environment
	environmentsQuery := octopusdeploy.EnvironmentsQuery{
		Name: environmentName,
	}
	environments, err := client.Environments.Get(environmentsQuery)
	if err != nil {
		log.Println(err)
	}

	// Loop through results
	for _, environment := range environments.Items {
		if environment.Name == environmentName {
			return environment
		}
	}

	return nil
}

func GetMachines(client *octopusdeploy.Client, machineNames []string, environment *octopusdeploy.Environment) []*octopusdeploy.DeploymentTarget {
	machineQuery := octopusdeploy.MachinesQuery{
		EnvironmentIDs: []string{environment.ID},
	}

	machines := []*octopusdeploy.DeploymentTarget{}

	// Chech to see if array is emtpy
	if len(machineNames) == 0 {
		results, err := client.Machines.Get(machineQuery)
		if err != nil {
			log.Println(err)
		}

		machines = append(machines, results.Items...)
	} else {
		for _, machineName := range machineNames {
			machineQuery.Name = machineName
			results, err := client.Machines.Get(machineQuery)
			if err != nil {
				log.Println(err)
			}

			machines = append(machines, results.Items...)
		}
	}

	return machines
}