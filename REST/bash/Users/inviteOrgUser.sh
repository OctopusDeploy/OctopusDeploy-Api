#!/bin/bash

## Bash script to programatically invite a new organization user via Octopus.com

# OCTOPUS_ORG, COOKIE, and RV_TOKEN variables can be acquired by inspecting a user invite web request from Octopus.com and copying as a curl request.
# User roles: 0 = Billing, 1 = Tech, 2 = Administrator

OCTOPUS_ORG="Organizations-xxx"
COOKIE=""
RV_TOKEN=""
NEW_USER_EMAIL="user%40domain.com"
NEW_USER_ROLE="0"

curl "https://octopus.com/invitation/$OCTOPUS_ORG/invite" \
  -H 'content-type: application/x-www-form-urlencoded' \
  -H "cookie: $COOKIE" \
  --data-raw "EmailAddress=$NEW_USER_EMAIL&role=$NEW_USER_ROLE&__RequestVerificationToken=$RV_TOKEN"
