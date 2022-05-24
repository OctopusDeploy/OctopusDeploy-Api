#!/bin/bash

# Define working variables
octopusUrl="https://your.octopus.app"
octopusApiKey="API-KEY"
spaceName="Default"
tenantName="Your Tenant Name"
projectName="Your Project Name"
environmentName="Your Environment Name"

echo "Getting space $spaceName"
spaces=$(curl -s -H "X-Octopus-ApiKey: $octopusApiKey" -X GET "$octopusUrl/api/spaces" -G --data-urlencode "partialName=$spaceName")
space_id=$(echo "$spaces" | jq ".Items[] | select(.Name==\"${spaceName}\") | .Id" -r)

echo "Getting project $projectName"
project=$(curl -L -X GET -H "X-Octopus-ApiKey: $octopusApiKey" "$octopusUrl/api/$space_id/projects?skip=0&take=1" -G --data-urlencode "partialName=$projectName" -H  "accept: application/json" | jq 'first(.Items[])' -r)
project_id=$(echo "${project}" | jq .Id -r)

echo "Getting environment $environmentName "
environment=$(curl -L -X GET -H "X-Octopus-ApiKey: $octopusApiKey" "$octopusUrl/api/$space_id/environments?skip=0&take=1" -G --data-urlencode "partialName=$environmentName" -H  "accept: application/json" | jq 'first(.Items[])' -r)
environment_id=$(echo "${environment}" | jq .Id -r)

# Get Tenant
echo "Getting tenant $tenantName"
tenant=$(curl -L -X GET -H "X-Octopus-ApiKey: $octopusApiKey" "$octopusUrl/api/$space_id/tenants?skip=0&take=1" -G --data-urlencode "partialName=$tenantName" -H  "accept: application/json" | jq 'first(.Items[])' -r)
tenant_id=$(echo "${tenant}" | jq .Id -r)
tenant_name=$(echo "${tenant}" | jq .Name -r)
tenant_tags=$(echo "${tenant}" | jq .TenantTags -r)
tenant_space_id=$(echo "${tenant}" | jq .SpaceId -r)
tenant_cloned_from=$(echo "${tenant}" | jq .ClonedFromTenantId -r)
tenant_desc=$(echo "${tenant}" | jq .Description -r)
tenant_links=$(echo "${tenant}" | jq .Links -r)
tenant_target_proj_envs=($(echo "${tenant}" | jq ".ProjectEnvironments | .[\"$project_id\"] | .[]" -r))
tenant_other_proj_envs=$(echo "${tenant}" | jq ".ProjectEnvironments | del(.\"$project_id\") | { ProjectEnvironments: . }")

echo "Adding new environment '$environment_id' to project connection (if needed)"
if [[ ! " ${tenant_target_proj_envs[@]} " =~ ${environment_id}  ]]; then
    tenant_target_proj_envs+=($environment_id)
else
    echo "Environment '$environment_id' already present on project for tenant"
    exit 0
fi

counter=0
project_envs=()
echo "Building new target project environment connections"
for project_env in ${tenant_target_proj_envs[@]}; do
  if [ $counter -eq 0 ]
    then
    project_envs="\"$project_env\""
    else
    project_envs="$project_envs,\"$project_env\""
  fi
  counter=$(expr $counter + 1)
done
echo "Creating project encironment connection json"
target_project_environment=$(jq -n \
            --arg projId "${project_id}" \
            --argjson peIds "[$project_envs]" \
            '{($projId): $peIds}' \
            )
target_project_environments=$(echo "$tenant_other_proj_envs" | jq --argjson tpe "${target_project_environment}" '.ProjectEnvironments += $tpe')
target_project_environments=$(echo "$target_project_environments" | jq ".ProjectEnvironments")

echo "Building final tenant json payload"
tenant_payload=$(jq -n \
            --arg tId "$tenant_id" \
            --arg tName "$tenant_name" \
            --argjson tTags "$tenant_tags" \
            --argjson pEnvs "$target_project_environments" \
            --arg tSpaceId "$tenant_space_id" \
            --argjson tClonedF "$tenant_cloned_from" \
            --argjson tDesc "$tenant_desc" \
            --argjson tLinks "$tenant_links" \
            '{Id: $tId, Name: $tName, TenantTags: $tTags, ProjectEnvironments: $pEnvs, SpaceId: $tSpaceId, ClonedFromTenantId: $tClonedF, Description: $tDesc, Links: $tLinks}' \
            )

echo "Updating tenant"
curl -X PUT -H "X-Octopus-ApiKey: $octopusApiKey" -H "Content-Type: application/json" "$octopusUrl/api/$space_id/tenants/$tenant_id" -d "$tenant_payload"