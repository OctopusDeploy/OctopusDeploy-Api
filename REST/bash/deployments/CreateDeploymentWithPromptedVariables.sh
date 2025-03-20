#!/usr/bin/env bash

# Configuration variables
octopusURL="https://.octopus.app"
apiKey="API-"
spaceName="Space Name"
projectName="Project Name"
releaseNumber="1.0"
environmentName="Environment Name"

# Define prompted variables in the format "VariableName::Value1;VariableName::Value2"
# Note: VariableName can contain multiple words and spaces, they'll be preserved
promptedVariableValues="VariableName::Value1;VariableName::Value2"

# Headers for API requests
headers=(
  -H "X-Octopus-ApiKey: $apiKey"
  -H "Content-Type: application/json"
)

# Function to make API requests
make_request() {
  local url="$1"
  response=$(curl -sS "${headers[@]}" "$url")
  if [[ $? -ne 0 || -z "$response" ]]; then
    echo "Error fetching data from $url" >&2
    exit 1
  fi
  echo "$response"
}

url_encode() {
  local raw="$1"
  echo -n "$raw" | jq -sRr @uri
}

# Fetch Space, Project, Environment IDs
encodedSpaceName=$(url_encode "$spaceName")
spaceId=$(make_request "$octopusURL/api/spaces?partialName=$encodedSpaceName&skip=0&take=1" | jq -r '.Items[0].Id')

encodedProjectName=$(url_encode "$projectName")
projectId=$(make_request "$octopusURL/api/$spaceId/projects?name=$encodedProjectName&skip=0&take=1" | jq -r '.Items[0].Id')

encodedEnvironmentName=$(url_encode "$environmentName")
environmentId=$(make_request "$octopusURL/api/$spaceId/environments?name=$encodedEnvironmentName&skip=0&take=1" | jq -r '.Items[0].Id')

encodedReleaseNumber=$(url_encode "$releaseNumber")
releaseId=$(make_request "$octopusURL/api/$spaceId/projects/$projectId/releases?searchByVersion=$encodedReleaseNumber&skip=0&take=1" | jq -r '.Items[0].Id')

deploymentPreview=$(make_request "$octopusURL/api/$spaceId/releases/$releaseId/deployments/preview/$environmentId?includeDisabledSteps=true")

# Check if deployment preview was successful
if ! echo "$deploymentPreview" | jq -e '.Form' >/dev/null 2>&1; then
  echo "ERROR: Failed to get deployment preview or it doesn't contain a Form"
  echo "$deploymentPreview" | jq .
  exit 1
fi

# Parse form elements
formElements=$(echo "$deploymentPreview" | jq '.Form.Elements')
elementCount=$(echo "$formElements" | jq 'length')

# Parse prompted variable values into an associative array
# Improved to handle multi-word variable names correctly
declare -A promptedVariables

# Split the string by semicolons, preserving any internal semicolons in the values
IFS=';' read -ra promptedValueList <<< "$promptedVariableValues"

for entry in "${promptedValueList[@]}"; do
  # Split at the first :: only to preserve any :: in the value
  varName="${entry%%::*}"
  varValue="${entry#*::}"
  
  # Trim spaces (but preserve internal spaces in both name and value)
  varName=$(echo "$varName" | xargs)
  varValue=$(echo "$varValue" | xargs)

  # Add value to the associative array
  if [[ -n "$varName" && -n "$varValue" ]]; then
    promptedVariables["$varName"]="$varValue"
  fi
done

# Debugging
#echo "Parsed prompted variables:"
#for key in "${!promptedVariables[@]}"; do
#  echo "  '$key' -> '${promptedVariables[$key]}'"
#done

# Initialize deployment JSON
deploymentFormValuesJson="{}"

# Process each form element properly using jq index access
for ((i=0; i<$elementCount; i++)); do
  # Extract each element as a complete JSON object
  element=$(echo "$formElements" | jq ".[$i]")
  
  # Extract needed fields
  varName=$(echo "$element" | jq -r '.Control.Name')
  uniqueName=$(echo "$element" | jq -r '.Name')
  isRequired=$(echo "$element" | jq -r '.Control.Required')
  varLabel=$(echo "$element" | jq -r '.Control.Label')
  
  if [[ -z "$varName" || "$varName" == "null" ]]; then
    echo "Skipping invalid or empty prompted variable..."
    continue
  fi

  # Look for an exact match by name
  if [[ -v "promptedVariables[$varName]" ]]; then
    value="${promptedVariables[$varName]}"
    deploymentFormValuesJson=$(jq --arg key "$uniqueName" --arg value "$value" \
      '. + {($key): $value}' <<< "$deploymentFormValuesJson")
    echo "Matched variable $varName, updating."
    continue
  fi
  
  # Try case-insensitive match
  matched=false
  for key in "${!promptedVariables[@]}"; do
    normalizedKey=$(echo "$key" | tr '[:upper:]' '[:lower:]' | xargs)
    normalizedVarName=$(echo "$varName" | tr '[:upper:]' '[:lower:]' | xargs)
    
    if [[ "$normalizedKey" == "$normalizedVarName" ]]; then
      value="${promptedVariables[$key]}"
      deploymentFormValuesJson=$(jq --arg key "$uniqueName" --arg value "$value" \
        '. + {($key): $value}' <<< "$deploymentFormValuesJson")
      echo "Matched variable $varName in case-insensitive search, updating."  
      matched=true
      break
    fi
  done
  
  # If we still haven't found a match, look for a match in the label
  if [[ "$matched" == "false" ]]; then
    for key in "${!promptedVariables[@]}"; do
      # Check if the label contains this key
      if [[ "$varLabel" == *"$key"* || "${varLabel// /}" == *"${key// /}"* ]]; then
        value="${promptedVariables[$key]}"
        deploymentFormValuesJson=$(jq --arg key "$uniqueName" --arg value "$value" \
          '. + {($key): $value}' <<< "$deploymentFormValuesJson")
        
        echo "Matched variable $varName on the label, updating."
        matched=true
        break
      fi
    done
  fi
  
  if [[ "$matched" == "false" && "$isRequired" == "true" ]]; then
    echo "  ERROR: No value provided for required variable: '$varName' (label: '$varLabel')"
    exit 1
  elif [[ "$matched" == "false" ]]; then
    echo "  Warning: No value provided for variable: '$varName' (label: '$varLabel')"
  fi
done

deploymentBody=$(jq -n \
  --arg releaseId "$releaseId" \
  --arg environmentId "$environmentId" \
  --argjson formValues "$deploymentFormValuesJson" \
  '{ReleaseId: $releaseId, EnvironmentId: $environmentId, FormValues: $formValues}')

echo "Creating deployment of $projectName release version $releaseNumber to $environmentName.."
deploymentResponse=$(curl -sS -X POST "${headers[@]}" -d "$deploymentBody" "$octopusURL/api/$spaceId/deployments")
deploymentUrl=$(echo "$deploymentResponse" | jq -r '.Links.Web')
echo "Deployment created, it can be accessed at $octopusURL$deploymentUrl "
