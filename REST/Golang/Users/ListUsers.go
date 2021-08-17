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

type UserDetails struct {
	Id              string
	Username        string
	DisplayName     string
	IsActive        string
	IsService       string
	EmailAddress    string
	ScopedUserRoles string
	AD_Upn          string
	AD_Sam          string
	AD_Email        string
	AAD_Dn          string
	AAD_Email       string
}

func main() {

	apiURL, err := url.Parse("https://YourUrl")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"
	csvExportPath := "path:\\to\\users.csv"
	includeUserRoles := true
	includeActiveDirectoryDetails := false
	includeAzureActiveDirectoryDetails := true
	includeInactiveUsers := false

	usersList := []UserDetails{}

	// Create client object
	client := octopusAuth(apiURL, APIKey, "")

	// Get all users
	users, err := client.Users.GetAll()
	if err != nil {
		log.Println(err)
	}

	// Loop through users
	for _, user := range users {
		if !includeInactiveUsers && !user.IsActive {
			continue
		}

		// record user information
		userDetails := UserDetails{}
		userDetails.Id = user.ID
		userDetails.Username = user.Username
		userDetails.DisplayName = user.DisplayName
		userDetails.IsActive = strconv.FormatBool(user.IsActive)
		userDetails.IsService = strconv.FormatBool(user.IsService)
		userDetails.EmailAddress = user.EmailAddress

		if includeUserRoles {
			userTeamNames, err := client.Users.GetTeams(user)
			if err != nil {
				log.Println(err)
			}

			for _, userTeamName := range *userTeamNames {
				team, err := client.Teams.GetByID(userTeamName.ID)
				if err != nil {
					log.Println(err)
				}

				roles, err := client.Teams.GetScopedUserRoles(*team, octopusdeploy.SkipTakeQuery{Skip: 0, Take: 1000})

				for _, role := range roles.Items {
					if role.SpaceID == "" {
						role.SpaceID = "Spaces-1"
					}
					space := GetSpace(apiURL, APIKey, role.SpaceID)
					userRole, err := client.UserRoles.GetByID(role.UserRoleID)
					if err != nil {
						log.Println(err)
					}
					userDetails.ScopedUserRoles += userRole.Name + " (" + space.Name + ")|"
				}
			}
		}

		for _, provider := range user.Identities {
			if provider.IdentityProviderName == "Active Directory" && includeActiveDirectoryDetails {
				userDetails.AD_Upn += provider.Claims["upn"].Value
				userDetails.AD_Sam += provider.Claims["sam"].Value
				userDetails.AD_Email += provider.Claims["email"].Value
			}
			if provider.IdentityProviderName == "Azure AD" && includeAzureActiveDirectoryDetails {
				userDetails.AAD_Dn += provider.Claims["dn"].Value
				userDetails.AAD_Email += provider.Claims["email"].Value
			}
		}

		usersList = append(usersList, userDetails)
	}

	if len(usersList) > 0 {
		fmt.Printf("Found %[1]s results \n", strconv.Itoa(len(usersList)))

		for i := 0; i < len(usersList); i++ {
			row := []string{}
			header := []string{}
			isFirstRow := false
			if i == 0 {
				isFirstRow = true
			}

			e := reflect.ValueOf(&usersList[i]).Elem()
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