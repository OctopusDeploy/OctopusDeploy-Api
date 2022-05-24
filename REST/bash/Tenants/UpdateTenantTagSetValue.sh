#!/bin/bash

# Define working variables
octopusUrl="https://your.octopus.app"
octopusApiKey="API-Key"
spaceName="Default"
tenantName="TenantName"
oldTagValue="9.0.3"
newTagValue="12.0.4"

# Get Space
spaces=$(curl -s -H "X-Octopus-ApiKey: $octopusApiKey" -X GET "$octopusUrl/api/spaces" -G --data-urlencode "partialName=$spaceName")
space_id=$(echo "$spaces" | jq ".Items[] | select(.Name==\"${spaceName}\") | .Id" -r)

# Get Tenant JSON
tenant=$(curl -L -X GET -H "X-Octopus-ApiKey: $octopusApiKey" "$octopusUrl/api/$space_id/tenants?skip=0&take=1" -G --data-urlencode "partialName=$tenantName" -H  "accept: application/json" | jq 'first(.Items[])' -r)

# Get Tenant ID
tenant_id=$(echo "${tenant}" | jq .Id -r)

# Modify tag value
tenant=$(echo "${tenant}" | sed -e "s/$oldTagValue/$newTagValue/g")

# Put tenant
curl -X PUT -H "X-Octopus-ApiKey: $octopusApiKey" -H "Content-Type: application/json" "$octopusUrl/api/$space_id/tenants/$tenant_id" -d "$tenant"