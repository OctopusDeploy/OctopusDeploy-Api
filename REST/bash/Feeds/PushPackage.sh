#! /bin/bash

# Define working variables
octopusURL="https://octopus.app"
octopusAPIKey="API-"
spaceName="Default"
packageFile="/path/to/file"

# Get space ID
spaceId=$(curl -s -H "X-Octopus-ApiKey: $octopusAPIKey" "$octopusURL/api/spaces/all" | jq -r ".[] | select(.Name == \"$spaceName\") | .Id")

if [ -z "$spaceId" ]; then
  echo "Error: Could not find space with name $spaceName"
  exit 1
fi

# Upload package
response=$(curl -s -w "%{http_code}" -o /dev/null -X POST "$octopusURL/api/$spaceId/packages/raw?replace=false" \
  -H "X-Octopus-ApiKey: $octopusAPIKey" \
  -F "fileData=@$packageFile")

if [ "$response" -ne 201 ]; then
  echo "Error: Failed to upload package"
  exit 1
fi

echo "Package uploaded successfully"
