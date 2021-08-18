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

	//spaceName := "Default"
	userRoleName := "Project deployer"

	// Create client object
	client := octopusAuth(apiURL, APIKey, "")

	// Get all teams
	teams, err := client.Teams.GetAll()
	if err != nil {
		log.Println(err)
	}

	// Get user role
	userRole := GetUserRoleByName(client, userRoleName)

	// Loop through teams
	for _, team := range teams {
		// Get scoped user roles
		scopedUserRoles, err := client.Teams.GetScopedUserRoles(*team, octopusdeploy.SkipTakeQuery{Skip: 0, Take: 1000})
		if err != nil {
			log.Println(err)
		}

		scopedUserRole := GetUserRole(scopedUserRoles.Items, userRole)

		if scopedUserRole != nil {
			fmt.Printf("Team: %[1]s \n", team.Name)
			fmt.Println("Users:")

			for _, userId := range team.MemberUserIDs {
				user, err := client.Users.GetByID(userId)
				if err != nil {
					log.Println(err)
				}

				fmt.Println(user.DisplayName)
			}

			if team.ExternalSecurityGroups != nil && len(team.ExternalSecurityGroups) > 0 {
				for _, group := range team.ExternalSecurityGroups {
					fmt.Println(group.DisplayIDAndName)
				}
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

func GetSpace(octopusURL *url.URL, APIKey string, spaceId string) *octopusdeploy.Space {
	client := octopusAuth(octopusURL, APIKey, "")

	// Get specific space object
	space, err := client.Spaces.GetByID(spaceId)

	if err != nil {
		log.Println(err)
	} else {
		fmt.Println("Retrieved space " + space.Name)
	}

	return space
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

func GetUserRole(roles []*octopusdeploy.ScopedUserRole, role *octopusdeploy.UserRole) *octopusdeploy.ScopedUserRole {
	for _, v := range roles {
		if v.UserRoleID == role.ID {
			return v
		}
	}

	return nil
}