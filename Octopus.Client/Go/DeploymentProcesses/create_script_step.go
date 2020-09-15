package main

import (
	"github.com/OctopusDeploy/go-octopusdeploy/client"
	"github.com/OctopusDeploy/go-octopusdeploy/model"
)

var (
	// Declare working variables
	octopusURL    string = "https://youroctourl"
	octopusAPIKey string = "API-YOURAPIKEY"
	spaceName     string = "default"
	projectName   string = "MyProject"
	roleName      string = "My role"
	scriptBody    string = "Write-Host \"Hello world\""
	stepName      string = "Run a script"
)

func main() {
	client, err := client.NewClient(nil, octopusURL, octopusAPIKey, spaceName)

	if err != nil {
		// TODO: handle error
	}

	// Get project
	project, err := client.Projects.GetByName(projectName)

	if err != nil {
		// TODO: handle error
	}

	// Get the deployment process
	deploymentProcess, err := client.DeploymentProcesses.Get(project.DeploymentProcessID)

	if err != nil {
		// TODO: handle error
	}

	// Create new step object
	newStep, err := model.NewDeploymentStep(stepName)

	if err != nil {
		// TODO: handle error
	}

	newStep.Condition = "Success"
	newStep.Properties["Octopus.Action.TargetRoles"] = roleName

	// Create new script action
	stepAction, err := model.NewDeploymentAction(stepName)

	if err != nil {
		// TODO: handle error
	}

	stepAction.ActionType = "Octopus.Script"
	stepAction.Properties["Octopus.Action.Script.ScriptBody"] = scriptBody

	// Add step action and step to process
	newStep.Actions = append(newStep.Actions, *stepAction)
	deploymentProcess.Steps = append(deploymentProcess.Steps, *newStep)

	// Update process
	updatedDeploymentProcess, err := client.DeploymentProcesses.Update(deploymentProcess)

	if err != nil {
		// TODO: handle error
	}
}
