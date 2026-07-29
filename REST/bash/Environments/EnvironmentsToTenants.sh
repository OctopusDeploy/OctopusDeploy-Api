#!/usr/bin/env bash

# Define working variables
octopusUrl="https://tam.octopus.app"
octopusApiKey=${OCTOPUS_TAM_API_KEY}
spaceName="Applied"       # Spaces-162
projectName="Parallel"    # Projects-481
gitRef=''

# Provide target environment names; one tenant will be created per environment.
environmentNames=("Dev-AL" "Dev-AK")
targetEnvironment="Development"

# Optional tenant tags to apply to all generated tenants.
tenantTags=("Env/Dev" "Region/South")

# Tag color used when creating missing tags.
tagColor="#007BFF"

deleteEnvironments=false
debugMode=false
forceMode=false
dryRunMode=false

usage() {
  cat <<'EOF'
Usage: $(basename "$0") [-u octopusUrl] [-s spaceName] [-p projectName] [-e environmentNames] [-te targetEnvironment] [-t tenantTags] [-d deleteEnvironments] [-h]

Create one tenant for each environment listed in environmentNames.

Options:
  -u octopusUrl     Override the default Octopus server URL.
  -s spaceName      Override the default space name.
  -p projectName    Override the default project name.
  -e environmentNames
                    Comma-separated list of environment names to create tenants for.
  -te targetEnvironment
                    Override the target environment that each created tenant is attached to.
  -t tenantTags     Comma-separated list of tenant tags to apply to each created tenant.
  -g gitRef         Indicate the git ref used for projects under source control.
  -rm               Remove environments after successful tenant creation.
  -force            Delete any existing tenant with the target name and recreate it.
  -dryrun           Run without making any changes; skips all non-GET API calls.
  -d                Enable debug mode and print extra tracing information.
  -h                Show this help message and exit.
EOF
}

debug() {
  if [ "$debugMode" = true ]; then
    printf 'DEBUG: %s\n' "$*" >&2
  fi
}

curl_with_check() {
  local method="$1"
  local url="$2"
  local data="$3"
  shift 3

  if [ "$dryRunMode" = true ] && [ "$method" != "GET" ]; then
    printf 'DRYRUN: would %s %s\n' "$method" "$url" >&2
    if [ -n "$data" ]; then
      debug "payload: $data"
    fi
    printf '{"Id": "dryrun-id"}'
    return 0
  fi

  debug "curl $method $url"

  local response
  if [ -n "$data" ]; then
    response=$(curl -sS -w "\n%{http_code}" -X "$method" -H "X-Octopus-ApiKey: $octopusApiKey" -H "Content-Type: application/json" "$url" -d "$data" "$@")
  else
    response=$(curl -sS -w "\n%{http_code}" -X "$method" -H "X-Octopus-ApiKey: $octopusApiKey" "$url" "$@")
  fi

  local http_code
  http_code=$(printf '%s' "$response" | tail -n 1)
  local body
  body=$(printf '%s\n' "$response" | sed '$d')

  if [ "$http_code" -ge 400 ]; then
    echo "ERROR: $method $url returned HTTP $http_code" >&2
    echo "$body" >&2
    return 1
  fi

  printf '%s' "$body"
}

while [ $# -gt 0 ]; do
  case "$1" in
    -u)
      if [ $# -lt 2 ]; then
        echo "Error: -u requires an argument." >&2
        usage
        exit 1
      fi
      shift
      octopusUrl="$1"
      ;;
    -s)
      if [ $# -lt 2 ]; then
        echo "Error: -s requires an argument." >&2
        usage
        exit 1
      fi
      shift
      spaceName="$1"
      ;;
    -p)
      if [ $# -lt 2 ]; then
        echo "Error: -p requires an argument." >&2
        usage
        exit 1
      fi
      shift
      projectName="$1"
      ;;
    -e)
      if [ $# -lt 2 ]; then
        echo "Error: -e requires an argument." >&2
        usage
        exit 1
      fi
      shift
      IFS=',' read -r -a environmentNames <<< "$1"
      ;;
    -te)
      if [ $# -lt 2 ]; then
        echo "Error: -te requires an argument." >&2
        usage
        exit 1
      fi
      shift
      targetEnvironment="$1"
      ;;
    -t)
      if [ $# -lt 2 ]; then
        echo "Error: -t requires an argument." >&2
        usage
        exit 1
      fi
      shift
      IFS=',' read -r -a tenantTags <<< "$1"
      ;;
    -g)
      if [ $# -lt 2 ]; then
        echo "Error: -g requires an argument." >&2
        usage
        exit 1
      fi
      shift
      gitRef="$1/"
      ;;
    -rm)
      deleteEnvironments=true
      ;;
    -force)
      forceMode=true
      ;;
    -dryrun)
      dryRunMode=true
      ;;
    -d)
      debugMode=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: invalid option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
 done

if [ "$debugMode" = true ]; then
  debug "octopusUrl=$octopusUrl"
  debug "spaceName=$spaceName"
  debug "projectName=$projectName"
  debug "environmentNames=${environmentNames[*]}"
  debug "targetEnvironment=$targetEnvironment"
  debug "tenantTags=${tenantTags[*]}"
  debug "gitRef=$gitRef"
  debug "deleteEnvironments=$deleteEnvironments"
  debug "forceMode=$forceMode"
  debug "dryRunMode=$dryRunMode"
fi

# Utility: convert bash array to JSON array for jq.
array_to_json() {
  if [ $# -eq 0 ]; then
    printf '[]'
    return
  fi
  printf '%s\n' "$@" | jq -R . | jq -s .
}

contains_element() {
  local needle="$1"
  shift
  local item
  if [ $# -eq 0 ]; then
    return 1
  fi

  for item in "$@"; do
    if [ "$item" = "$needle" ]; then
      return 0
    fi
  done

  return 1
}

contains_element_in_multiline() {
  local needle="$1"
  local haystack="$2"
  local item

  while IFS= read -r item; do
    if [ "$item" = "$needle" ]; then
      return 0
    fi
  done <<EOF
$haystack
EOF

  return 1
}

ensure_tagset_tag_exists() {
  local fullTag="$1"
  local tagsetName="${fullTag%%/*}"
  local tagName="${fullTag#*/}"

  local encodedName
  encodedName=$(printf '%s' "$tagsetName" | jq -sRr @uri)
  local tagset_response
  tagset_response=$(curl_with_check GET "$octopusUrl/api/$space_id/tagsets?name=$encodedName" "")
  local tagset_id
  tagset_id=$(echo "$tagset_response" | jq -r --arg name "$tagsetName" '.Items[] | select(.Name==$name) | .Id' | head -n 1)

  if [ -z "$tagset_id" ] || [ "$tagset_id" = "null" ]; then
    printf 'Creating tagset %s with tag %s\n' "$tagsetName" "$tagName"
    local tags_json
    tags_json=$(jq -n --arg name "$tagName" --arg color "$tagColor" '[{Id: null, Name: $name, Color: $color, Description: "", CanonicalTagName: null}]')
    local payload
    payload=$(jq -n --arg name "$tagsetName" --arg desc "Created by script" --argjson tags "$tags_json" '{Name: $name, Description: $desc, Tags: $tags}')
    curl_with_check POST "$octopusUrl/api/$space_id/tagsets" "$payload" >/dev/null
    return
  fi

  local current_tags
  current_tags=$(curl_with_check GET "$octopusUrl/api/$space_id/tagsets/$tagset_id" "" | jq -r '.Tags[].Name')
  if contains_element_in_multiline "$tagName" "$current_tags"; then
    printf 'Tagset %s already contains tag %s\n' "$tagsetName" "$tagName"
    return
  fi

  printf 'Adding tag %s to tagset %s\n' "$tagName" "$tagsetName"
  local new_tag_json
  new_tag_json=$(jq -n --arg name "$tagName" --arg color "$tagColor" '{Id: null, Name: $name, Color: $color, Description: "", CanonicalTagName: null}')
  local updated_payload
  updated_payload=$(curl_with_check GET "$octopusUrl/api/$space_id/tagsets/$tagset_id" "" | jq --argjson newTag "$new_tag_json" '.Tags += [$newTag]')
  curl_with_check PUT "$octopusUrl/api/$space_id/tagsets/$tagset_id" "$updated_payload" >/dev/null
}

ensure_tagsets_exist() {
  local fullTag

  for fullTag in "${tenantTags[@]}"; do
    if [[ "$fullTag" != */* ]]; then
      echo "ERROR: tenant tag '$fullTag' must be in TagSet/Tag format" >&2
      exit 1
    fi
    ensure_tagset_tag_exists "$fullTag"
  done
}

# Get space
printf 'Getting space %s\n' "$spaceName"
spaces=$(curl_with_check GET "$octopusUrl/api/spaces" "" -G --data-urlencode "name=$spaceName")
space_id=$(echo "$spaces" | jq -r ".Items[] | select(.Name==\"${spaceName}\") | .Id")
if [ -z "$space_id" ] || [ "$space_id" == "null" ]; then
  echo "ERROR: space '$spaceName' not found"
  exit 1
fi

# Get project
printf 'Getting project %s\n' "$projectName"
project=$(curl_with_check GET "$octopusUrl/api/$space_id/projects?skip=0&take=1" "" -G --data-urlencode "name=$projectName" -H "accept: application/json")

project_id=$(echo "$project" | jq -r 'first(.Items[]).Id')
if [ -z "$project_id" ] || [ "$project_id" == "null" ]; then
  echo "ERROR: project '$projectName' not found in space '$spaceName'"
  exit 1
fi

versionControlled=$(echo "$project" | jq -r 'first(.Items[]).IsVersionControlled')
if [ "$versionControlled" == "true" ] && [ "$gitRef" == "" ]; then
  echo "ERROR: project '$projectName' is under Source Control"
  echo "       please specify the git ref using -g <gitRef> (e.g., -g main)"
  exit 1
fi

if [ ${#tenantTags[@]} -gt 0 ]; then
  printf 'Ensuring tenant tagsets and tags exist\n'
  ensure_tagsets_exist
fi

# Fetch all project variables once; scoping is updated in memory as each tenant is created
# and written back after the loop.
printf 'Fetching variables for project %s\n' "$projectName"
variable_set=$(curl_with_check GET "$octopusUrl/api/$space_id/projects/$project_id/${gitRef}variables" "" -H "accept: application/json")
#
# XX remove
#
echo "$variable_set" | jq .Variables

# Get target environment; created tenants are attached to this environment.
printf 'Resolving target environment %s\n' "$targetEnvironment"
target_environment=$(curl_with_check GET "$octopusUrl/api/$space_id/environments?skip=0&take=1" "" -G --data-urlencode "name=$targetEnvironment" -H "accept: application/json" | jq 'first(.Items[])' -r)
target_environment_id=$(echo "$target_environment" | jq -r .Id)
if [ -z "$target_environment_id" ] || [ "$target_environment_id" == "null" ]; then
  printf 'Target environment %s not found; creating it\n' "$targetEnvironment"
  target_environment_payload=$(jq -n --arg name "$targetEnvironment" '{Name: $name}')
  target_environment=$(curl_with_check POST "$octopusUrl/api/$space_id/environments" "$target_environment_payload")
  target_environment_id=$(echo "$target_environment" | jq -r .Id)
fi

if [ -z "$target_environment_id" ] || [ "$target_environment_id" == "null" ]; then
  echo "ERROR: failed to resolve or create target environment '$targetEnvironment'"
  exit 1
fi

# Get all existing tenants once so we can skip duplicate names.
printf 'Fetching existing tenants in space %s\n' "$spaceName"
tenants=$(curl_with_check GET "$octopusUrl/api/$space_id/tenants/all" "")

#tenant_tags_json=$(array_to_json "${tenantTags[@]}")
tenant_tags_json=$(printf '%s\n' "${tenantTags[@]}" | jq -R . | jq -s 'map(@json) |   join(",") ')

for environmentName in "${environmentNames[@]}"; do
  printf '\nProcessing environment: %s\n' "$environmentName"

  existingTenantId=$(echo "$tenants" | jq -r --arg name "$environmentName" '.[] | select(.Name==$name) | .Id' | head -n 1)
  if [ -n "$existingTenantId" ]; then
    if [ "$forceMode" != true ]; then
      echo "Skipping creation: tenant already exists with name '$environmentName' (ID: $existingTenantId)"
      continue
    fi

    printf 'Force mode: deleting existing tenant %s (ID: %s)\n' "$environmentName" "$existingTenantId"
    curl_with_check DELETE "$octopusUrl/api/$space_id/tenants/$existingTenantId" "" >/dev/null
  fi

  printf 'Resolving environment %s\n' "$environmentName"
  environment=$(curl_with_check GET "$octopusUrl/api/$space_id/environments?skip=0&take=1" "" -G --data-urlencode "name=$environmentName" -H "accept: application/json" | jq 'first(.Items[])' -r)
  environment_id=$(echo "$environment" | jq -r .Id)

  if [ -z "$environment_id" ] || [ "$environment_id" == "null" ]; then
    echo "WARNING: environment '$environmentName' not found; skipping"
    continue
  fi

  printf 'Creating tenant for environment %s (ID: %s)\n' "$environmentName" "$environment_id"

  project_environments=$(jq -n --arg projectId "$project_id" --arg environmentId "$target_environment_id" '{($projectId): ([$environmentId] | unique)}')
  tenant_payload=$(jq -n \
    --arg name "$environmentName" \
    --arg spaceId "$space_id" \
    --argjson tenantTags "$tenant_tags_json" \
    --argjson projectEnvironments "$project_environments" \
    '{Name: $name, SpaceId: $spaceId, TenantTags: $tenantTags, ProjectEnvironments: $projectEnvironments}')

  response=$(curl_with_check POST "$octopusUrl/api/$space_id/tenants" "$tenant_payload")
  echo "Tenant creation response for '$environmentName':"
  echo "$response" | jq .

  tenant_id=$(echo "$response" | jq -r '.Id // empty')
  if [ -n "$tenant_id" ]; then
    printf 'Rescoping project variables from environment %s (ID: %s) to environment %s (ID: %s)\n' "$environmentName" "$environment_id" "$targetEnvironment" $target_environment_id
    variable_set=$(echo "$variable_set" | jq \
      --arg envId "$environment_id" \
      --arg targetEnvId "$target_environment_id" \
      --arg tenantTags "$tenantTags" \
      '.Variables |= map(
        if ((.Scope.Environment // []) | index($envId)) then
          .Scope.Environment = (((.Scope.Environment // []) - [$envId]) + [$targetEnvId] | unique)
          | .Scope.TenantTag = (((.Scope.TenantTag // []) + [$tenantTags]) | unique)
        else
          .
        end
      )')
  fi
  #       --arg tenantId "$tenant_id" \
  #  | .Scope.Tenant = (((.Scope.Tenant // []) + [$tenantId]) | unique)
  debug "variable set: $variable_set"
  
  if [ "$deleteEnvironments" = true ]; then
    printf 'Deleting environment %s (ID: %s)\n' "$environmentName" "$environment_id"
    delete_response=$(curl_with_check DELETE "$octopusUrl/api/$space_id/environments/$environment_id" "")
    echo "Delete response for environment '$environmentName':"
    echo "$delete_response" | jq .
  fi
done

# Persist the rescoped project variables (environment -> target environment + tenant).
printf '\nUpdating project variables with new environment/tenant scoping\n'
curl_with_check PUT "$octopusUrl/api/$space_id/projects/$project_id/${gitRef}variables" "$variable_set" >/dev/null

# Allow the project to be deployed tenanted or untenanted, since tenants were just added.
printf '\nUpdating project %s to allow TenantedOrUntenanted deployments\n' "$projectName"
project_resource=$(curl_with_check GET "$octopusUrl/api/$space_id/projects/$project_id" "")
updated_project=$(echo "$project_resource" | jq '.TenantedDeploymentMode = "TenantedOrUntenanted"')
curl_with_check PUT "$octopusUrl/api/$space_id/projects/$project_id" "$updated_project" >/dev/null
