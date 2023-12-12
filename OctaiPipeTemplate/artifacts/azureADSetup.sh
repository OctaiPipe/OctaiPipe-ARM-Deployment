#!/bin/bash
set -e

while getopts ":c:s:t:u:" opt; do
  case $opt in
    a) appId="$OPTARG" ;;
    o) objectId="$OPTARG" ;;
    s) clientSecret="$OPTARG" ;;
    t) tenantId="$OPTARG" ;;
    g) groupId="$OPTARGS" ;;
    \?) echo -e "\r\nInvalid option -$OPTARG" >&2 ;;
  esac
done

az login --service-principal -u ${appId} -p ${clientSecret} -t ${tenantId} --allow-no-subscription

echo -e "\r\nLogged to to az with Service Principal!"

az ad app update --id $appId --app-roles '[
  {
    "allowedMemberTypes": ["User", "Application"],
    "displayName": "Readers",
    "description": "Access OctaiClient API",
    "isEnabled": true,
    "value": "Task.Read",
    "id": "81dd5fd5-e1d3-47dc-b008-c4d1bf94e145"
  }
]'

# Set Global Variables
# readersAppRoleId=$(uuidgen)
readersAppRoleId=$readersAppRoleIdGuid

app=$appId
sp=$(az ad sp show --id ${appId} --query id -o tsv)

# Setup Authentication
nativeClient='https://login.microsoftonline.com/common/oauth2/nativeclient'
liveSDK='https://login.live.com/oauth20_desktop.srf'
msalonly="msal$appId://auth"
az ad app update --id $appId --public-client-redirect-uris "http://localhost" $nativeClient $liveSDK $msalonly
echo -e "\r\nAuthentication setup complete!"


# Allow public client flows set to True 
az rest --method PATCH --uri "https://graph.microsoft.com/v1.0/applications(appId='$appId')" --headers 'Content-Type=application/json' --body '{"isFallbackPublicClient": true}'

# Create a new AppRoleAssignment for the Group
appRolebody="{
  \"principalId\": \"$groupId\",
  \"resourceId\": \"$sp\",
  \"appRoleId\": \"$readersAppRoleId\"
}"
az rest --method POST --uri "https://graph.microsoft.com/v1.0/groups/$groupId/appRoleAssignments" --body "$appRolebody" --headers 'Content-Type=application/json'
echo -e "\r\nNew AppRoleAssignment for the group created!"

# # Create JSON output
# output_json="{
#   \"objectId\": \"$objectId\",
# }"
# echo -e "\r\nJSON output created!"

# # Write JSON to AZ_SCRIPTS_OUTPUT_PATH
# echo $output_json > $AZ_SCRIPTS_OUTPUT_PATH