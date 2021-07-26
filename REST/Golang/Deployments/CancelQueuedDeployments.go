package main

import (
	"encoding/json"
	"fmt"
	"log"

	"net/http"
	"net/url"

	"io/ioutil"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

func main() {

	apiURL, err := url.Parse("http://YourURL")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"
	spaceName := "Default"

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	canContinue := true

	for canContinue {
		tasks := GetQueuedTasks(apiURL, APIKey, space)

		//fmt.Println(tasks)
		for i := 0; i < len(tasks); i++ {
			task := tasks[i].(map[string]interface{})
			CancelTask(apiURL, APIKey, space, task["Id"].(string))
		}

		if len(tasks) == 0 {
			canContinue = false
		}
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

func GetQueuedTasks(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space) []interface{} {
	// Query api for tasks
	tasksApi := octopusURL.String() + "/api/" + space.ID + "/tasks?States=Queued&Name=Deploy"

	// Create http client
	httpClient := &http.Client{}

	// perform request
	request, _ := http.NewRequest("GET", tasksApi, nil)
	request.Header.Set("X-Octopus-ApiKey", APIKey)
	response, err := httpClient.Do(request)

	if err != nil {
		log.Println(err)
	}

	responseData, err := ioutil.ReadAll(response.Body)

	var f interface{}
	jsonErr := json.Unmarshal(responseData, &f)
	if jsonErr != nil {
		log.Println(err)
	}

	tasks := f.(map[string]interface{})

	// return the tasks
	return tasks["Items"].([]interface{})
}

func CancelTask(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, TaskId string) {
	// create http client
	httpClient := &http.Client{}

	// perform post
	tasksApi := octopusURL.String() + "/api/" + space.ID + "/tasks/" + TaskId + "/cancel"
	request, _ := http.NewRequest("POST", tasksApi, nil)
	request.Header.Set("X-Octopus-ApiKey", APIKey)
	response, err := httpClient.Do(request)
	fmt.Println(tasksApi)

	if err != nil {
		log.Println(err)
	}

	if response.StatusCode == 200 {
		fmt.Println("Task " + TaskId + " has been cancelled.")
	}
}