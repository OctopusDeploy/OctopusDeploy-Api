#!/bin/bash

## Bash script to programatically invite a new instance user via Octopus.com

# Cookie and token variables can be acquired by inspecting a user invite web request from Octopus.com and copying as a curl request.

LICENSE_KEY="licensekeys-xxx"
OCTOPUS_TEAM="Everyone"
OCTOPUS_ORG="Organizations-xxx"
COOKIE=""
RV_TOKEN=""
NEW_USER_EMAIL="user%40domain.com"
NEW_USER_FULLNAME=""
SEND_INVITE="true"

curl "https://octopus.com/invitation" \
  -H "content-type: application/x-www-form-urlencoded" \
  -H "cookie: $COOKIE" \
  --data-raw "OrganizationId=$OCTOPUS_ORG&LicenseId=$LICENSE_KEY&Email=$NEW_USER_EMAIL&FullName=$NEW_USER_FULLNAME&TargetSystemTeam=$OCTOPUS_TEAM&SendInvite=$SEND_INVITE&__RequestVerificationToken=$RV_TOKEN&SendInvite=false" 