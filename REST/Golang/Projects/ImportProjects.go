package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"time"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

type ImportProject struct {
	ImportSource ImportSource
	Password     *octopusdeploy.SensitiveValue
}

type ImportSource struct {
	Type    string
	SpaceId string
	TaskId  string
}

func main() {

	apiURL, err := url.Parse("https://YourURL")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"
	destinationSpaceName := "Destination Space"
	exportPassword := "MyFanatasticPassword"
	exportTaskId := "ServerTasks-XXXXX"

	// Get reference to space
	destinationSpace := GetSpace(apiURL, APIKey, destinationSpaceName)


	// Build body
	password := octopusdeploy.NewSensitiveValue(exportPassword)
	importObject := ImportProject{}
	importObject.ImportSource.SpaceId = destinationSpace.ID
	importObject.ImportSource.TaskId = exportTaskId
	importObject.ImportSource.Type = "space"
	importObject.Password = password

	// Export the projects
	ImportProjects(apiURL, APIKey, destinationSpace, importObject, true, 300)

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

func ImportProjects(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, importProjects ImportProject, waitForFinish bool, taskCancelInSeconds int) {
	// Create http client
	httpClient := &http.Client{}
	exportTaskUrl := octopusURL.String() + "/api/" + space.ID + "/projects/import-export/import"

	// Make request
	jsonBody, err := json.Marshal(importProjects)
	myString := string(jsonBody)
	fmt.Println(myString)
	if err != nil {
		log.Println(err)
	}

	request, _ := http.NewRequest("POST", exportTaskUrl, bytes.NewBuffer(jsonBody))
	request.Header.Set("X-Octopus-ApiKey", APIKey)
	response, err := httpClient.Do(request)

	if err != nil {
		log.Println(err)
	}

	responseData, err := ioutil.ReadAll(response.Body)

	var serverTaskRaw interface{}
	jsonErr := json.Unmarshal(responseData, &serverTaskRaw)
	if jsonErr != nil {
		log.Println(err)
	}

	// Get the task id
	serverTask := serverTaskRaw.(map[string]interface{})
	serverTaskId := serverTask["TaskId"]
	fmt.Println("The task id of the new task is: " + serverTaskId.(string))

	if waitForFinish {
		fmt.Println("The setting to wait for completion was set, waiting until the task has finished")

		elapsedSeconds := 0
		taskUrl := octopusURL.String() + "/api/" + space.ID + "/tasks/" + serverTaskId.(string)

		for elapsedSeconds < taskCancelInSeconds {
			time.Sleep(5 * time.Second)
			elapsedSeconds += 5

			request, _ := http.NewRequest("GET", taskUrl, nil)
			request.Header.Set("X-Octopus-ApiKey", APIKey)
			response, err := httpClient.Do(request)

			if err != nil {
				log.Println(err)
			}

			responseData, err := ioutil.ReadAll(response.Body)

			var serverTaskRaw interface{}
			jsonErr := json.Unmarshal(responseData, &serverTaskRaw)
			if jsonErr != nil {
				log.Println(err)
			}
			serverTask = serverTaskRaw.(map[string]interface{})
			taskStatus := serverTask["State"]

			if taskStatus.(string) == "Success" {
				fmt.Println("The task has finished successfully")
				break

			} else if taskStatus.(string) == "Failed" || taskStatus.(string) == "Cancelled" {
				fmt.Println("The task finished with a status of " + taskStatus.(string))
				break
			}
		}

		if elapsedSeconds >= taskCancelInSeconds {
			cancelUrl := octopusURL.String() + "/api/" + space.ID + "/tasks/" + serverTaskId.(string) + "/cancel"
			request, _ := http.NewRequest("GET", cancelUrl, nil)
			request.Header.Set("X-Octopus-ApiKey", APIKey)
			response, err := httpClient.Do(request)

			if err != nil {
				log.Println(err)
			}
			fmt.Println(response)
		}
	}
}