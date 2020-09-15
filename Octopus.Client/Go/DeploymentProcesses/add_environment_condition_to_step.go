package main

import (
	"github.com/OctopusDeploy/go-octopusdeploy/client"
)

var (
	// Declare working variables
	octopusURL       string   = "https://youroctourl"
	octopusAPIKey    string   = "API-YOURAPIKEY"
	spaceName        string   = "default"
	projectName      string   = "MyProject"
	environmentNames []string = {"Development", "Test"}
)

func main() {
	client, err := client.NewClient(nil, octopusURL, octopusAPIKey, spaceName)

	if err != nil {
		// TODO: handle error
	}

	environmentIDs := []string{}

	for _, environmentName := range environmentNames {
		environmentID, err := client.Environments.FindByName(environmentName)

		if err != nil {
			// TODO: handle error
		}

		environmentIDs = append(environmentIDs, environmentID)
	}

	project, err := client.Projects.FindByName(projectName)

	if err != nil {
		// TODO: handle error
	}

	deploymentProcess, err := client.DeploymentProcesses.Get(project.DeploymentProcessID)

	if err != nil {
		// TODO: handle error
	}

	for _, step := range deploymentProcess.Steps {
		if step.Name == stepName {
			for _, action := range step.Actions {
				for _, environmentID := range environmentIDs {
					action.Environments = append(action.Environments, environmentID)
				}
			}
		}
	}

	updatedDeploymentProcess, err := client.DeploymentProcesses.Update(deploymentProcess)

	if err != nil {
		// TODO: handle error
	}
}
