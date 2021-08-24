package main

import (
	"fmt"
	"log"

	"net/url"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"
)

func main() {

	apiURL, err := url.Parse("https://YourUrl")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"
	spaceName := "Default"
	environmentNames := []string{"Development", "Production"}
	teamName := "MyTeam"
	userRoleName := "MyRole"

	// Get reference to space
	space := GetSpace(apiURL, APIKey, spaceName)

	// Get reference to team
	team := GetTeam(apiURL, APIKey, space, teamName, 0)

	// Get reference to userrole
	userRole := GetRole(apiURL, APIKey, space, userRoleName)

	// Get scoped user role
	scopedUserRole := GetScopedUserRole(apiURL, APIKey, space, userRole, team)

	// Get references to environments
	for i := 0; i < len(environmentNames); i++ {
		environment := GetEnvironment(apiURL, APIKey, space, environmentNames[i])
		//environments = append(environments, *environment)
		scopedUserRole.EnvironmentIDs = append(scopedUserRole.EnvironmentIDs, environment.ID)
	}

	// Update scoped user role
	client := octopusAuth(apiURL, APIKey, space.ID)
	client.ScopedUserRoles.Update(scopedUserRole)
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

func GetEnvironment(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, environmentName string) *octopusdeploy.Environment {
	// Get client for space
	client := octopusAuth(octopusURL, APIKey, space.ID)

	// Get environment
	environmentsQuery := octopusdeploy.EnvironmentsQuery {
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

func GetTeam(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, TeamName string, skip int) *octopusdeploy.Team {
	client := octopusAuth(octopusURL, APIKey, space.ID)

	// Create query
	teamsQuery := octopusdeploy.TeamsQuery{
		PartialName: TeamName,
		Spaces:      []string{space.ID},
	}

	// Query for team
	teams, err := client.Teams.Get(teamsQuery)
	if err != nil {
		log.Println(err)
	}

	if len(teams.Items) == teams.ItemsPerPage {
		// call again
		team := GetTeam(client, space, TeamName, (skip + len(teams.Items)))

		if team != nil {
			return team
		}
	} else {
		// Loop through returned items
		for _, team := range teams.Items {
			if team.Name == TeamName {
				return team
			}
		}
	}

	return nil
}

func GetRole(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, RoleName string) *octopusdeploy.UserRole {
	client := octopusAuth(octopusURL, APIKey, space.ID)

	// Get user account
	userRoleQuery := octopusdeploy.UserRolesQuery{
		PartialName: RoleName,
	}

	userRoles, err := client.UserRoles.Get(userRoleQuery)

	if err != nil {
		log.Println(err)
	}

	for i := 0; i < len(userRoles.Items); i++ {
		if userRoles.Items[i].Name == RoleName {
			fmt.Println("Retrieved UserRole " + userRoles.Items[i].Name)
			return userRoles.Items[i]
		}
	}

	return nil
}

func GetScopedUserRole(octopusURL *url.URL, APIKey string, space *octopusdeploy.Space, userRole *octopusdeploy.UserRole, team *octopusdeploy.Team) *octopusdeploy.ScopedUserRole {
	client := octopusAuth(octopusURL, APIKey, space.ID)

	/*
		There is a bug currently where the Get() method doesn't take the query as a parameter, once that has been fixed, this block will work

	*/
	//scopedUserRoleQuery := octopusdeploy.ScopedUserRolesQuery {
	//	PartialName: userRole.Name,
	//}

	// Get scoped user role
	scopedUserRoles, err := client.ScopedUserRoles.Get()

	if err != nil {
		log.Println(err)
	}

	// Loop through results to find the correct one
	for i := 0; i < len(scopedUserRoles.Items); i++ {
		if scopedUserRoles.Items[i].UserRoleID == userRole.ID {
			return scopedUserRoles.Items[i]
		}
	}

	return nil
}

func contains(s []string, str string) bool {
	for _, v := range s {
		if v == str {
			return true
		}
	}

	return false
}