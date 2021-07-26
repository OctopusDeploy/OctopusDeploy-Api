package main

import (
	"fmt"
	"log"
	"os"

	"net/url"

	"github.com/OctopusDeploy/go-octopusdeploy/octopusdeploy"

	"encoding/csv"
	"io"
)

type User struct {
	OctopusUsername   string
	AzureEmailAddress string
	AzureDisplayName  string
}

func main() {

	apiURL, err := url.Parse("https://YourUrl")
	if err != nil {
		log.Println(err)
	}
	APIKey := "API-YourAPIKey"

	Path := ""
	Users := []User{}
	OctopusUsername := ""
	AzureEmailAddress := ""
	AzureDisplayName := ""
	OverwriteEmailAddress := false
	OverwriteDisplayName := false

	if Path != "" {
		Users = GetCSVData(Path)
	} else {
		u := User{OctopusUsername: OctopusUsername, AzureEmailAddress: AzureEmailAddress, AzureDisplayName: AzureDisplayName}
		Users = append(Users, u)
	}

	for i := 0; i < len(Users); i++ {
		// Get existing user account
		existingUser := GetUser(apiURL, APIKey, Users[i].OctopusUsername)

		// Check to see if something was returned
		if existingUser != nil {
			fmt.Println("Found " + existingUser.Username)

			// Check to see if it has an identity
			if existingUser.Identities != nil {
				identityIndex := -1
				// Loop through Identities collection
				for j := 0; j < len(existingUser.Identities); j++ {
					if existingUser.Identities[i].IdentityProviderName == "Azure AD" {
						fmt.Println("User has existing Azure AD identity")
						identityIndex = j
						break
					}
				}

				if identityIndex > -1 {
					if OverwriteDisplayName {
						existingUser.DisplayName = Users[i].AzureDisplayName
					}

					if OverwriteEmailAddress {
						existingUser.EmailAddress = Users[i].AzureEmailAddress
					}

				} else {
					// Create new identity object
					claimsCollection := make(map[string]octopusdeploy.IdentityClaim)
					emailClaim := octopusdeploy.IdentityClaim{Value: Users[i].AzureEmailAddress, IsIdentifyingClaim: true}
					displayNameClaim := octopusdeploy.IdentityClaim{Value: Users[i].AzureDisplayName, IsIdentifyingClaim: false}
					claimsCollection["email"] = emailClaim
					claimsCollection["dn"] = displayNameClaim
					octopusIdentity := octopusdeploy.Identity{IdentityProviderName: "Azure AD", Claims: claimsCollection}

					// Add new identity
					existingUser.Identities = append(existingUser.Identities, octopusIdentity)
				}

				// Update user account
				client := octopusAuth(apiURL, APIKey, "")
				existingUser, err = client.Users.Update(existingUser)

				if err != nil {
					log.Println(err)
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

func GetUser(octopusURL *url.URL, APIKey string, OctopusUserName string) *octopusdeploy.User {
	// Get client
	client := octopusAuth(octopusURL, APIKey, "")

	// Get user account
	userQuery := octopusdeploy.UsersQuery{
		Filter: OctopusUserName,
	}

	userAccounts, err := client.Users.Get(userQuery)

	if err != nil {
		log.Println(err)
	}

	for i := 0; i < len(userAccounts.Items); i++ {
		// Check to see if it's a match
		if userAccounts.Items[i].Username == OctopusUserName {
			return userAccounts.Items[i]
		}
	}

	return nil
}

func GetCSVData(Path string) []User {
	recordFile, err := os.Open(Path)

	if err != nil {
		log.Println(err)
	}

	Users := []User{}

	reader := csv.NewReader(recordFile)
	reader.Comma = ','

	for i := 0; ; i++ {
		record, err := reader.Read()

		if err == io.EOF {
			break
		}

		userAccount := User{OctopusUsername: record[0], AzureEmailAddress: record[1], AzureDisplayName: record[2]}

		Users = append(Users, userAccount)
	}

	return Users
}