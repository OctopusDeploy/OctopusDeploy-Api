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
	teamName := "MyTeam"

	// Get the space object
	space := GetSpace(apiURL, APIKey, spaceName)

	// Creat client for space
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Get team
	team := GetTeam(client, teamName, space)

	// Get project
	project, err := client.Projects.GetByName(projectName)
	if err != nil {
		log.Println(err)
	}

	// Get the scoped user roles for the team
	scopedUserRoles, err := client.Teams.GetScopedUserRoles(*team, octopusdeploy.SkipTakeQuery{Skip: 0, Take: 1000})
	if err != nil {
		log.Println(err)
	}


	// Loop through scoped user roles
	for _, scopedUserRole := range scopedUserRoles.Items {
		if arrayContains(scopedUserRole.ProjectIDs, project.ID) {
			// Rebuild slice without that Id
			fmt.Printf("Removing %[1]s from %[2]s \n", team.Name, project.Name)
			scopedUserRole.ProjectIDs = RemoveFromArray(scopedUserRole.ProjectIDs, project.ID)
			client.ScopedUserRoles.Update(scopedUserRole)
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

func GetTeam(client *octopusdeploy.Client, teamName string, space *octopusdeploy.Space) *octopusdeploy.Team {
	// Get list of teams
	teams, err := client.Teams.GetByPartialName(teamName)
	if err != nil {
		log.Println(err)
	}

	for _, team := range teams {
		if team.SpaceID == space.ID && team.Name == teamName {
			return team
		}
	}

	return nil
}

func arrayContains(s []string, str string) bool {
	for _, v := range s {
		if v == str {
			return true
		}
	}

	return false
}

func RemoveFromArray(items []string, item string) []string {
	newItems := []string{}
	for _, entry := range items {
		if entry != item {
			newItems = append(newItems, entry)
		}
	}

	return newItems
}