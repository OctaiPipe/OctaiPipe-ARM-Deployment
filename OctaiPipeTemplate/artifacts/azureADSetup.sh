#!/bin/bash
set -e

while getopts "a:o:s:t:g:" opt; do
  case $opt in
    a) appId="$OPTARG" ;;
    o) objectId="$OPTARG" ;;
    s) clientSecret="$OPTARG" ;;
    t) tenantId="$OPTARG" ;;
    g) groupId="$OPTARGS" ;;
    \?) echo -e "\r\nInvalid option -$OPTARG" >&2 ;;
  esac
done

# Remove subscriptins bit if necessary (temp hardcode)
# tenantId="9485acfb-a348-4a74-8408-be47f710df4b" # ${tenantId/\/subscriptions\//}

az login --service-principal -u ${appId} -p ${clientSecret} -t ${tenantId} --allow-no-subscription

echo -e "\r\nLogged to to az with Service Principal!"

# Set Global Variables
# readersAppRoleId=$(uuidgen)
readersAppRoleId=$readersAppRoleIdGuid

taskReadAppRole="[
  {
    \"allowedMemberTypes\": [\"User\", \"Application\"],
    \"displayName\": \"Readers\",
    \"description\": \"Access OctaiClient API\",
    \"isEnabled\": true,
    \"value\": \"Task.Read\",
    \"id\": \"$readersAppRoleId\"
  }
]"

az ad app update --id $appId --app-roles "$taskReadAppRole"
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