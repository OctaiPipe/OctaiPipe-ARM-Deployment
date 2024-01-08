#!/bin/bash
set -e

while getopts "a:c:s:t:g:" opt; do
  case $opt in
    a) appId="$OPTARG" ;;
    c) customerName="$OPTARG" ;;
    s) clientSecret="$OPTARG" ;;
    t) tenantId="$OPTARG" ;;
    g) groupId="$OPTARG" ;;
    \?) echo -e "\r\nInvalid option -$OPTARG" >&2 ;;
  esac
done

az login --service-principal -u ${appId} -p ${clientSecret} -t ${tenantId} --allow-no-subscription

echo -e "\r\nLogged to to az with Service Principal!"


taskReadAppRole="[
  {
    \"allowedMemberTypes\": [\"User\", \"Application\"],
    \"displayName\": \"Readers\",
    \"description\": \"Access OctaiClient API\",
    \"isEnabled\": true,
    \"value\": \"Task.Read\",
    \"id\": \"$readersAppRoleIdGuid\"
  }
]"

# Add Readers role to app
sp=$(az ad sp show --id ${appId} --query id -o tsv)
if update_output=$(az ad app update --id $appId --app-roles "$taskReadAppRole" 2>&1); then
    echo -e "\r\nReaders Role added to App!"
elif [[ $update_output == *"unless disabled first"* ]]; then
    echo -e "\r\nReaders Role already on App. Error: $update_output"
else
    echo -e "\r\nFailed to add Readers Role to App. Error: $update_output"
    exit 1
fi

# Setup Authentication
nativeClient='https://login.microsoftonline.com/common/oauth2/nativeclient'
liveSDK='https://login.live.com/oauth20_desktop.srf'
msalonly="msal$appId://auth"
az ad app update --id $appId --public-client-redirect-uris "http://localhost" $nativeClient $liveSDK $msalonly

webAppAddress="https://octaipipe-mlops-$customerName.azurewebsites.net"
webAppAddressAlias="https://app.$customerName.octaipipe.ai"
az ad app update --id $appId --identifier-uris api://$appId
az ad app update --id $appId --enable-id-token-issuance true

az rest --method "patch" \
  --uri "https://graph.microsoft.com/v1.0/applications/1a3d87b0-7595-40b2-aeca-1028a88a2969" \
  --headers "Content-Type=application/json" \
  --body "{\"spa\": {\"redirectUris\": [\"$webAppAddress\", \"$webAppAddressAlias\", \
          \"$webAppAddress/swagger/oauth2-redirect.html\", \"$webAppAddressAlias/swagger/oauth2-redirect.html\", \
          \"http://localhost:44474\", \"http://localhost:44474/swagger/oauth2-redirect.html\"]}}"

echo -e "\r\nAuthentication setup complete!"


# Allow public client flows set to True 
az rest --method PATCH --uri "https://graph.microsoft.com/v1.0/applications(appId='$appId')" --headers 'Content-Type=application/json' --body '{"isFallbackPublicClient": true}'
echo -e "\r\nPublic Client flows allowed!"

# Create a new AppRoleAssignment for the Group
readersAppRoleId=$(az ad app show --id $appId --query "appRoles[?displayName=='Readers'].id" -o tsv)
appRoleBody="{
  \"principalId\": \"$groupId\",
  \"resourceId\": \"$sp\",
  \"appRoleId\": \"$readersAppRoleId\"
}"
echo -e "\r\nUsing ${appRoleBody} as payload to assign role to ${groupId}"

if update_output=$(az rest --method POST --uri "https://graph.microsoft.com/v1.0/groups/$groupId/appRoleAssignments" --body "$appRoleBody" --headers 'Content-Type=application/json' 2>&1); then
    echo -e "\r\nNew AppRoleAssignment for the group created!"
elif [[ $update_output == *"already exists on the object"* ]]; then
    echo -e "\r\nAppRoleAssignment exists for the group. Output: $update_output"
else
    echo -e "\r\nFailed to add Readers Role to App. Error: $update_output"
    exit 1
fi

echo -e "\nAzure AD setup complete!"
# # Create JSON output
# output_json="{
#   \"appId\": \"$appId\",
# }"
# echo -e "\r\nJSON output created!"

# # Write JSON to AZ_SCRIPTS_OUTPUT_PATH
# echo $output_json > $AZ_SCRIPTS_OUTPUT_PATH