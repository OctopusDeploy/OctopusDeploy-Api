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
	Id           string
	Username     string
	DisplayName  string
	IsActive     string
	IsService    string
	EmailAddress string
	Permissions  string
}

func main() {

	apiURL, err := url.Parse("https://YourURL")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"
	csvExportPath := "path:\\to\\editpermissions.csv"

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

		// Get user permissions
		userPermissions, err := client.Users.GetPermissions(user)
		editPermissions := []string{}

		if err != nil {
			log.Println(err)
		}

		// Loop through the permissions
		v := reflect.ValueOf(userPermissions.SpacePermissions)
		for i := 0; i < v.NumField(); i++ {
			if strings.Contains(v.Type().Field(i).Name, "Create") || strings.Contains(v.Type().Field(i).Name, "Delete") || strings.Contains(v.Type().Field(i).Name, "Edit") {
				permissionRestrictions := v.Field(i).Interface().([]octopusdeploy.UserPermissionRestriction)

				if len(permissionRestrictions) > 0 {
					editPermissions = append(editPermissions, v.Type().Field(i).Name)
				}
			}
		}

		if len(editPermissions) > 0 {
			// record user information
			userDetails := UserDetails{}
			userDetails.Id = user.ID
			userDetails.Username = user.Username
			userDetails.DisplayName = user.DisplayName
			userDetails.IsActive = strconv.FormatBool(user.IsActive)
			userDetails.IsService = strconv.FormatBool(user.IsService)
			userDetails.EmailAddress = user.EmailAddress
			userDetails.Permissions = strings.Join(editPermissions, "|")

			usersList = append(usersList, userDetails)
		}
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