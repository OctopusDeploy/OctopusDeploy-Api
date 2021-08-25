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
	tenantName := "MyTenant"
	variableTemplateName := "MyTemplate"
	newValue := "MyValue"

	// Get the space object
	space := GetSpace(apiURL, APIKey, spaceName)

	// Create client for space
	client := octopusAuth(apiURL, APIKey, space.ID)

	// Get tenant
	tenant := GetTenant(client, tenantName, 0)

	tenantVariables, err := client.Tenants.GetVariables(tenant)
	if err != nil {
		log.Println(err)
	}

	// Loop through the project variables
	for i, projectVariables := range tenantVariables.ProjectVariables {
		projectTemplate := octopusdeploy.ActionTemplateParameter{}
		for _, template := range projectVariables.Templates {
			if template.Name == variableTemplateName {
				projectTemplate = *template
				break
			}
		}

		for environment, variables := range projectVariables.Variables {
			fmt.Println(environment)
			for template, element := range variables {
				if template == projectTemplate.ID {
					newPropertyValue := octopusdeploy.NewPropertyValue(newValue, element.IsSensitive)
					element = newPropertyValue
					tenantVariables.ProjectVariables[i].Variables[environment][template] = element
				}
			}
		}
	}

	// Update tenant variables
	tenantVariables, err = client.Tenants.UpdateVariables(tenant, tenantVariables)
	if err != nil {
		log.Println(err)
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

func GetTenant(client *octopusdeploy.Client, tenantName string, skip int) *octopusdeploy.Tenant {
	tenantQuery := octopusdeploy.TenantsQuery{
		Name: tenantName,
	}

	// Get tenants
	tenants, err := client.Tenants.Get(tenantQuery)

	if err != nil {
		log.Println(err)
	}

	// Check what's been returned
	if len(tenants.Items) == tenants.ItemsPerPage {
		tenant := GetTenant(client, tenantName, (skip + len(tenants.Items)))

		if tenant != nil {
			return tenant
		}
	} else {
		// Loop through
		for _, tenant := range tenants.Items {
			if tenant.Name == tenantName {
				return tenant
			}
		}
	}

	return nil
}