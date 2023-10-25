#!/bin/bash
set -e

az login --service-principal --tenant $AZURE_TENANT_ID --username $AZURE_CLIENT_ID --password $AZURE_CLIENT_SECRET

echo "Logged to to az with Service Princiapl!"


# Default values
sp="4d144ad5-ec4c-4e9a-b1f2-e462aa1950e9"
app=$AZURE_CLIENT_ID
customerName="finale5"
subscriptionId="0376d230-c884-4b5d-80b2-6759120231fc"
tenantId="9485acfb-a348-4a74-8408-be47f710df4b"
userEmails_str="michael.tobin@octaipipe.ai,sdfSFDA SDF,A SD,FA SD, FA,FS DF,A SD,SD,FAFDA , ASDFASD, ASDF"

while getopts ":c:s:t:u:" opt; do
  case $opt in
    sp) sp="$OPTARG" ;;
    a) app="$OPTARG" ;;
    c) customerName="$OPTARG" ;;
    s) subscriptionId="$OPTARG" ;;
    t) tenantId="$OPTARG" ;;
    u) userEmails_str="$OPTARG" ;;
    \?) echo "Invalid option -$OPTARG" >&2 ;;
  esac
done


echo "Setting up AD for $customerName !"
IFS=',' read -ra userEmails <<< "$userEmails_str"

# Check user emails input is valid before running anything
notFoundEmails=()
for userEmail in "${userEmails[@]}"
do
  userId=$(az ad user list --query "[?mail=='$userEmail'].id | [0]" -o tsv)
  if [ -z "$userId" ]; then
    notFoundEmails+=("$userEmail")
  fi
done
if [ ${#notFoundEmails[@]} -ne 0 ]; then
    echo "Error: The following emails were not found:"
    for email in "${notFoundEmails[@]}"; do
    echo "$email"
    done
exit 1
fi
echo "Email validation complete!"

# Global Variables
readersAppRoleId=$(uuidgen)

# Set Azure Context
az account set --subscription $subscriptionId
echo "Azure context set!"

# # Create AppRoles
# appRoles="[
#   {
#     \"allowedMemberTypes\": [\"User\", \"Application\"],
#     \"displayName\": \"Readers\",
#     \"description\": \"Access OctaiClient API\",
#     \"isEnabled\": true,
#     \"value\": \"Task.Read\",
#     \"id\": \"$readersAppRoleId\"
#   }
# ]"

# # Create App and Service Principal
# app=$(az ad app create --display-name "${customerName}-admin" --sign-in-audience AzureADMyOrg --app-roles "$appRoles" --query appId -o tsv)
# objectId=$(az ad app list --filter "appId eq '$app'" --query "[].id" -o tsv)
# sp=$(az ad sp create --id $app --query id -o tsv)
# az ad sp update --id $sp --set "appRoleAssignmentRequired=true"
# echo "App and Service Principal created!"

# # Wait for propagation
# sleep 20

# # Assign Role
# az role assignment create --assignee $sp --role Owner --scope "/subscriptions/$subscriptionId"
# echo "Role assignment complete!"

# Create App Role (assuming this part in json format)
# TODO: Replace this section with actual commands for creating App Role

# Get service principal for Microsoft Graph
graphSp=$(az ad sp list --filter "AppId eq '00000003-0000-0000-c000-000000000000'" --query "[0].id" -o tsv)
graphRoles=$(az ad sp show --id $graphSp --query "appRoles" -o json)
echo "Service principal for Microsoft Graph obtained!"

applicationReadWriteRoleId=$(echo $graphRoles | jq -r '.[] | select(.value == "Application.ReadWrite.All") | .id')
groupReadAllRoleId=$(echo $graphRoles | jq -r '.[] | select(.value == "Group.Read.All") | .id')
userReadRoleId=$(echo $graphRoles | jq -r '.[] | select(.value == "User.Read") | .id')
userReadAllRoleId=$(echo $graphRoles | jq -r '.[] | select(.value == "User.Read.All") | .id')
mailSendRoleId=$(echo $graphRoles | jq -r '.[] | select(.value == "Mail.Send") | .id')

az ad app permission add --id $app --api $app --api-permissions $readersAppRoleId=Role 2>/dev/null
az ad app permission add --id $app --api 00000003-0000-0000-c000-000000000000 --api-permissions $applicationReadWriteRoleId=Role 2>/dev/null
az ad app permission add --id $app --api 00000003-0000-0000-c000-000000000000 --api-permissions $groupReadAllRoleId=Role 2>/dev/null
# Cannot retrieve User.Read guid so hardcoding
az ad app permission add --id $app --api 00000003-0000-0000-c000-000000000000 --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope 2>/dev/null
az ad app permission add --id $app --api 00000003-0000-0000-c000-000000000000 --api-permissions $userReadAllRoleId=Role 2>/dev/null
az ad app permission add --id $app --api 00000003-0000-0000-c000-000000000000 --api-permissions $mailSendRoleId=Role 2>/dev/null
echo "Permissions added!"

# Grant permissions
if az ad app permission admin-consent --id $app 2>/dev/null; then
  echo "Permissions granted!"
else
  echo "Unable to grant permission - please get an administrator to do so."
fi


# Setup Authentication
nativeClient='https://login.microsoftonline.com/common/oauth2/nativeclient'
liveSDK='https://login.live.com/oauth20_desktop.srf'
msalonly="msal$app://auth"
az ad app update --id $app --public-client-redirect-uris "http://localhost" $nativeClient $liveSDK $msalonly
echo "Authentication setup complete!"

# Allow public client flows set to True 
az rest --method PATCH --uri "https://graph.microsoft.com/v1.0/applications(appId='$app')" --headers 'Content-Type=application/json' --body '{"isFallbackPublicClient": true}'

# User and Group Assignment
groupName="${customerName}-octaipipe-users"
groupId=$(az ad group create --display-name $groupName --mail-nickname "NotUsed" --description "Group For OctaiPipe Users" --query id -o tsv)
echo "User and Group Assignment complete!"

# Assign Service Principal as Owner
az ad group owner add --group $groupId --owner-object-id $sp

# Create a new AppRoleAssignment for the Group
appRolebody="{
  \"principalId\": \"$groupId\",
  \"resourceId\": \"$sp\",
  \"appRoleId\": \"$readersAppRoleId\"
}"
az rest --method POST --uri "https://graph.microsoft.com/v1.0/groups/$groupId/appRoleAssignments" --body "$appRolebody" --headers 'Content-Type=application/json'
echo "New AppRoleAssignment for the group created!"

# Assign Users
for userEmail in "${userEmails[@]}"
do
  userId=$(az ad user list --query "[?mail=='$userEmail'].id | [0]" -o tsv)
  az ad group member add --group $groupId --member-id $userId
done
echo "Users assigned to group!"

# Create Client Secret
clientSecret=$(az ad app credential reset --id $app --append --display-name "OctaiPipe Secret" --years 4 --query password -o tsv)
echo "Client secret created!"

# Create JSON output
output_json="{
  \"clientId\": \"$app\",
  \"azureAdGroupName\": \"$groupName\",
  \"azureAdGroupId\": \"$groupId\",
  \"objectId\": \"$objectId\",
  \"servicePrincipalSecret\": \"$clientSecret\"
}"
echo "JSON output created!"

# Write JSON to AZ_SCRIPTS_OUTPUT_PATH
echo $output_json > $AZ_SCRIPTS_OUTPUT_PATH
