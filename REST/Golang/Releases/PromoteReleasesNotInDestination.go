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
	projectNames := []string{"MyProject"}
	sourceEnvironmentName := "Production"
	destinationEnvironmentName := "Test"

	// Get space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client object
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Get source environment
	sourceEnvironment := GetEnvironmentByName(client, sourceEnvironmentName)

	destinationEnvironment := GetEnvironmentByName(client, destinationEnvironmentName)

	// Loop through projects
	for _, projectName := range projectNames {
		// Get the project
		project := GetProject(apiURL, APIKey, space, projectName)

		fmt.Printf("The project Id for project name %[1]s is %[2]s \n", project.Name, project.ID)
		fmt.Printf("I have all the Ids I need, I am going to find the most recent successful deployment to %[1]s \n", sourceEnvironment.Name)

		// Get task list
		taskQuery := octopusdeploy.TasksQuery{
			Environment: sourceEnvironment.ID,
			Project:     project.ID,
			States:      []string{"Success"},
			Spaces:      []string{space.ID},
		}
		sourceTaskList, err := client.Tasks.Get(taskQuery)
		if err != nil {
			log.Println(err)
		}

		if len(sourceTaskList.Items) == 0 {
			fmt.Printf("Unable to find a successful deployment for project %[1]s to %[2]s \n", project.Name, sourceEnvironment.Name)
			continue
		}

		latestSourceDeploymentTask := sourceTaskList.Items[0]
		latestSourceDeploymentId := latestSourceDeploymentTask.Arguments["DeploymentId"].(string)

		fmt.Printf("The Id of the last deployment for project %[1]s to %[2]s is %[3]s \n", project.Name, sourceEnvironment.Name, latestSourceDeploymentId)
		latestSourceDeployment, err := client.Deployments.GetByID(latestSourceDeploymentId)
		if err != nil {
			log.Println(err)
		}

		fmt.Printf("The release Id for %[1]s is %[2]s \n", latestSourceDeployment.ID, latestSourceDeployment.ReleaseID)

		canPromote := false

		fmt.Printf("I have all the Ids I need, I am going to find the recent successful deployment to %[1]s \n", destinationEnvironment.Name)

		// Get destination task list
		taskQuery.Environment = destinationEnvironment.ID
		destinationTaskList, err := client.Tasks.Get(taskQuery)
		if err != nil {
			log.Println(err)
		}

		if len(destinationTaskList.Items) == 0 {
			fmt.Printf("The destination has no releases, promoting \n")
			canPromote = true
		}

		// Get the latest task
		latestDestinationDeploymentTask := destinationTaskList.Items[0]
		latestDestinationDeploymentId := latestDestinationDeploymentTask.Arguments["DeploymentId"].(string)

		fmt.Printf("The Id of the last deployment for project %[1]s to %[2]s is %[3]s \n", project.Name, destinationEnvironment.Name, latestDestinationDeploymentId)
		latestDestinationDeployment, err := client.Deployments.GetByID(latestDestinationDeploymentId)
		if err != nil {
			log.Println(err)
		}

		fmt.Printf("The release Id for %[1]s is %[2]s \n", latestDestinationDeployment.ID, latestDestinationDeployment.ReleaseID)

		if latestDestinationDeployment.ReleaseID != latestSourceDeployment.ReleaseID {
			fmt.Printf("The releases on the source and destination do not match, promoting \n")
			canPromote = true
		} else {
			fmt.Printf("The releases match, not promoting \n")
		}

		if !canPromote {
			fmt.Printf("Nothing to promote for project %[1]s \n", project.Name)
		}

		deployment := octopusdeploy.NewDeployment(destinationEnvironment.ID, latestSourceDeployment.ReleaseID)
		client.Deployments.Add(deployment)
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

func GetUserRoleByName(client *octopusdeploy.Client, roleName string) *octopusdeploy.UserRole {
	// Get all user roles
	userRoles, err := client.UserRoles.GetAll()
	if err != nil {
		log.Println(err)
	}

	// Loop through roles
	for _, role := range userRoles {
		if role.Name == roleName {
			return role
		}
	}

	return nil
}

func GetEnvironmentByName(client *octopusdeploy.Client, environmentName string) *octopusdeploy.Environment {
	environments, err := client.Environments.GetByName(environmentName)
	if err != nil {
		log.Println(err)
	}

	for _, environment := range environments {
		if environment.Name == environmentName {
			return environment
		}
	}

	return nil
}

func GetProject(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, projectName string) *octopusdeploy.Project {
	// Create client
	client := octopusAuth(octopusURL, APIKey, space.ID)

	projectsQuery := octopusdeploy.ProjectsQuery {
		Name: projectName,
	}

	// Get specific project object
	projects, err := client.Projects.Get(projectsQuery)

	if err != nil {
		log.Println(err)
	}

	for _, project := range projects.Items {
		if project.Name == projectName {
			return project
		}
	}

	return nil
}