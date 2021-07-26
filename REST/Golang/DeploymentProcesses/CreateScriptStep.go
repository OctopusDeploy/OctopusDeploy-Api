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
	projectName := "MyProject"
	stepName := "MyStep"
	scriptBody := "Write-Host \"Hello world\""
	roleName := "MyRole"

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client object
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Get project
	project := GetProject(client, projectName)

	// Get deployment process
	deploymentProcess := GetDeploymentProcess(client, project)

	// Create new step object
	step := octopusdeploy.DeploymentStep{
		Name: stepName,
	}

	step.Condition = octopusdeploy.DeploymentStepConditionTypeSuccess
	step.StartTrigger = octopusdeploy.DeploymentStepStartTriggerStartAfterPrevious
	step.PackageRequirement = octopusdeploy.DeploymentStepPackageRequirementLetOctopusDecide
	roleProperties := []octopusdeploy.PropertyValue{}
	roleProperty := octopusdeploy.PropertyValue{
		IsSensitive: false,
		Value:       roleName,
	}
	roleProperties = append(roleProperties, roleProperty)

	stepProperties := make(map[string][]octopusdeploy.PropertyValue)
	stepProperties["Octopus.Action.TargetRoles"] = roleProperties

	// Create action
	action := octopusdeploy.DeploymentAction{
		IsDisabled: false,
		IsRequired: false,
	}
	action.IsDisabled = false
	action.IsRequired = false
	actionScriptBody := octopusdeploy.NewPropertyValue(scriptBody, false)
	actionProperties := make(map[string]octopusdeploy.PropertyValue)
	actionProperties["Octopus.Action.Script.ScriptBody"] = actionScriptBody
	action.Properties = actionProperties

	// Add action to step
	step.Actions = append(step.Actions, action)

	// Add to process
	deploymentProcess.Steps = append(deploymentProcess.Steps, step)
	client.DeploymentProcesses.Update(deploymentProcess)
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

func GetProject(client *octopusdeploy.Client, projectName string) *octopusdeploy.Project {
	// Get project
	project, err := client.Projects.GetByName(projectName)

	if err != nil {
		log.Println(err)
	}

	if project != nil {
		fmt.Println("Retrieved project " + project.Name)
	} else {
		fmt.Println("Project " + projectName + " not found!")
	}

	return project
}

func GetDeploymentProcess(client *octopusdeploy.Client, project *octopusdeploy.Project) *octopusdeploy.DeploymentProcess {
	deploymentProcess, err := client.DeploymentProcesses.GetByID(project.DeploymentProcessID)

	if err != nil {
		log.Println(err)
	}

	return deploymentProcess
}