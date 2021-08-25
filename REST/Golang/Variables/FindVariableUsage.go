package main

import (
	"bufio"
	"fmt"
	"log"
	"net/url"
	"os"
	"reflect"
	"strconv"
	"strings"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

type VariableResult struct {
	Project           string
	MatchType         string
	Context           string
	Property          string
	AdditionalContext string
	Link              string
}

func main() {

	apiURL, err := url.Parse("https://YourURL")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"
	spaceName := "Default"
	variableToFind := "MyProject.Variable"
	searchDeploymentProcess := true
	searchRunbookProcess := true
	csvExportPath := "path:\\to\\variable.csv"

	// Create client object
	client := octopusAuth(apiURL, APIKey, "")

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	client = octopusAuth(apiURL, APIKey, space.ID)

	variableTracking := []VariableResult{}

	// Get projects
	projects, err := client.Projects.GetAll()
	if err != nil {
		log.Println(err)
	}

	// Loop through projects
	for _, project := range projects {
		fmt.Printf("Checking %[1]s \n", project.Name)

		// Get variables
		projectVariables, err := client.Variables.GetAll(project.ID)

		if err != nil {
			log.Println(err)
		}

		for _, variable := range projectVariables.Variables {
			nameMatch := strings.Contains(variable.Name, variableToFind)
			if err != nil {
				log.Println(err)

			}

			if nameMatch {
				result := VariableResult{}
				result.Project = project.Name
				result.MatchType = "Named Project Variable"
				result.Context = variable.Name
				result.Property = ""
				result.AdditionalContext = variable.Value
				result.Link = project.Links["Variables"]

				if !arrayContains(variableTracking, result) {
					variableTracking = append(variableTracking, result)
				}

			}

			valueMatch := strings.Contains(variable.Value, variableToFind)
			if err != nil {
				log.Println(err)
			}

			if valueMatch {
				result := VariableResult{}
				result.Project = project.Name
				result.MatchType = "Referenced Project Variable"
				result.Context = variable.Name
				result.Property = ""
				result.AdditionalContext = variable.Value
				result.Link = project.Links["Variables"]

				if !arrayContains(variableTracking, result) {
					variableTracking = append(variableTracking, result)
				}

			}
		}

		if searchDeploymentProcess {
			if !project.IsVersionControlled {
				// Get deployment process
				deploymentProcess, err := client.DeploymentProcesses.GetByID(project.DeploymentProcessID)
				if err != nil {
					log.Println(err)
				}

				for _, step := range deploymentProcess.Steps {
					for _, action := range step.Actions {
						for property := range action.Properties {
							if strings.Contains(action.Properties[property].Value, variableToFind) {
								result := VariableResult{}
								result.Project = project.Name
								result.MatchType = "Step"
								result.Context = step.Name
								result.Property = property
								result.AdditionalContext = ""
								result.Link = apiURL.String() + project.Links["Web"] + "/deployments/process/stesp?actionId=" + action.ID

								if !arrayContains(variableTracking, result) {
									variableTracking = append(variableTracking, result)
								}
							}
						}
					}
				}
			} else {
				fmt.Printf("%[1]s is version controlled, skipping searching deployment process", project.Name)
			}
		}

		if searchRunbookProcess {
			// Get project runbooks
			runbooks := GetRunbooks(client, project)

			// Loop through runbooks
			for _, runbook := range runbooks {
				// Get runbook process
				runbookProcess, err := client.RunbookProcesses.GetByID(runbook.RunbookProcessID)
				if err != nil {
					log.Println(err)
				}

				for _, step := range runbookProcess.Steps {
					for _, action := range step.Actions {
						for property := range action.Properties {
							if strings.Contains(action.Properties[property].Value, variableToFind) {
								result := VariableResult{}
								result.Project = project.ID
								result.MatchType = "Runbook Step"
								result.Context = runbook.Name
								result.Property = property
								result.AdditionalContext = step.Name
								result.Link = apiURL.String() + project.Links["Web"] + "/operations/runbooks/" + runbook.ID + "/process/" + runbook.RunbookProcessID + "/steps?actionId=" + action.ID

								if !arrayContains(variableTracking, result) {
									variableTracking = append(variableTracking, result)
								}
							}
						}
					}
				}
			}
		}
	}

	if len(variableTracking) > 0 {
		fmt.Printf("Found %[1]s results \n", strconv.Itoa(len(variableTracking)))

		for i := 0; i < len(variableTracking); i++ {
			row := []string{}
            header := []string{}
			isFirstRow := false
			if i == 0 {
				isFirstRow = true
			}

			e := reflect.ValueOf(&variableTracking[i]).Elem()
			for j := 0; j < e.NumField(); j++ {
				if isFirstRow {
					header = append(header, e.Type().Field(j).Name)
				}
				row = append(row, e.Field(j).Interface().(string))
			}

			if csvExportPath != "" {
				file, err := os.OpenFile(csvExportPath, os.O_APPEND|os.O_WRONLY|os.O_CREATE, 0600)
				if err != nil {
					log.Println(err)
				}

				dataWriter := bufio.NewWriter(file)
				if isFirstRow {
					dataWriter.WriteString(strings.Join(header, ",") + "\n")
				}
				dataWriter.WriteString(strings.Join(row, ",") + "\n")
				dataWriter.Flush()
				file.Close()
			}

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

func arrayContains(array []VariableResult, result VariableResult) bool {
	for _, v := range array {
		if v == result {
			return true
		}
	}

	return false
}

func GetRunbooks(client *octopusdeploy.Client, project *octopusdeploy.Project) []*octopusdeploy.Runbook {
	// Get runbook
	runbooks, err := client.Runbooks.GetAll()
	projectRunbooks := []*octopusdeploy.Runbook{}

	if err != nil {
		log.Println(err)
	}

	for i := 0; i < len(runbooks); i++ {
		if runbooks[i].ProjectID == project.ID {
			projectRunbooks = append(projectRunbooks, runbooks[i])
		}
	}

	return projectRunbooks
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