param (
    [string]$customerName # = "arm-autodeploy-test-second-pass",
    [string]$subscriptionId # = "0376d230-c884-4b5d-80b2-6759120231fc",
    [string]$tenantId = # "9485acfb-a348-4a74-8408-be47f710df4b",
    [string]$userEmails # = "michael.tobin@t-dab.com, ivan.scattergood@t-dab.com, michael.tobin27@outlook.com"  # This will be a comma-separated string
)

$userEmails = $userEmails -split ','  # Split the string back into an array

# Global Varibles
$readersAppRoleId = [Guid]::NewGuid().ToString()

# Functions for installing the Az module and setting Azure context
function Setup-AzureContext {
    # Install the Az module
    Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force

    # Login to Azure AD
    Connect-AzAccount -TenantId $tenantId -Subscription $subscriptionId

    # Set your subscription
    Set-AzContext -SubscriptionId $subscriptionId
}

# Function for creating new application, service principal and assigning owner role
function Create-AppAndSP {
    # Create the App registration
    $app = New-AzADApplication -DisplayName "${customerName}-admin" -AvailableToOtherTenants $false 

    # Create Service Principal and assign Owner role
    $sp = New-AzADServicePrincipal -AppId $app.AppId

    # Wait for propagation
    Start-Sleep -Seconds 20

    # Assign role
    New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName 'Owner'

    # return app and service principal
    return $app, $sp
}

# Function for connecting to Azure AD, creating an application role and assigning permissions
function Setup-AppRoleAndPermissions($app, $sp) {
    # Connect to Azure AD
    Connect-AzureAD

    # Create an application role of given name and description
    # Create new AppRole object
    $newAppRole = [Microsoft.Open.AzureAD.Model.AppRole]::new()
    $newAppRole.AllowedMemberTypes = New-Object System.Collections.Generic.List[string]
    $newAppRole.AllowedMemberTypes.Add("User")
    $newAppRole.AllowedMemberTypes.Add("Application")
    $newAppRole.DisplayName = "Readers"
    $newAppRole.Description = "Access OctaiClient API"
    $newAppRole.Value = "Task.Read"
    $newAppRole.Id = $readersAppRoleId
    $newAppRole.IsEnabled = $true

    $appRoles = $App.AppRoles
    $appRoles += $newAppRole
    echo $appRoles

    Set-AzureADApplication -ObjectId $app.Id -AppRoles $appRoles

    # Get the service principal for the Microsoft Graph
    $graphSp = Get-AzureADServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

    # Get the AppRoleId for the "Task.Read" permission
    $appRole = $sp.AppRoles | Where-Object { $_.Value -eq "Task.Read" }
    $taskReadRoleId = $appRole.Id

    # Get the AppRoleId for the "Application.ReadWrite.All" permission
    $appRole = $graphSp.AppRoles | Where-Object { $_.Value -eq "Application.ReadWrite.All" }
    $appReadWriteAllRoleId = $appRole.Id

    # Get the AppRoleId for the "Group.Read.All" permission
    $appRole = $graphSp.AppRoles | Where-Object { $_.Value -eq "Group.Read.All" }
    $groupReadAllRoleId = $appRole.Id

    # Get the AppRoleId for the "User.Read" permission
    $appRole = $graphSp.AppRoles | Where-Object { $_.Value -eq "User.Read" }
    $userReadRoleId = $appRole.Id

    # Get the AppRoleId for the "User.Read.All" permission
    $appRole = $graphSp.AppRoles | Where-Object { $_.Value -eq "User.Read.All" }
    $userReadAllRoleId = $appRole.Id

    # Get the AppRoleId for "Mail.Send" permission
    $appRole = $graphSp.AppRoles | Where-Object { $_.Value -eq 'Mail.Send' }
    $mailSendRoleId = $appRole.Id

    # Assign the permissions to your service principal
    New-AzureADServiceAppRoleAssignment -ObjectId $sp.ObjectId -PrincipalId $sp.ObjectId -Id $taskReadRoleId -ResourceId $sp.ObjectId
    New-AzureADServiceAppRoleAssignment -ObjectId $sp.ObjectId -PrincipalId $sp.ObjectId -Id $appReadWriteAllRoleId -ResourceId $graphSp.ObjectId
    New-AzureADServiceAppRoleAssignment -ObjectId $sp.ObjectId -PrincipalId $sp.ObjectId -Id $groupReadAllRoleId -ResourceId $graphSp.ObjectId
    New-AzureADServiceAppRoleAssignment -ObjectId $sp.ObjectId -PrincipalId $sp.ObjectId -Id $userReadRoleId -ResourceId $graphSp.ObjectId
    New-AzureADServiceAppRoleAssignment -ObjectId $sp.ObjectId -PrincipalId $sp.ObjectId -Id $userReadAllRoleId -ResourceId $graphSp.ObjectId
    New-AzureADServiceAppRoleAssignment -ObjectId $sp.ObjectId -PrincipalId $sp.ObjectId -Id $mailSendRoleId -ResourceId $graphSp.ObjectId
}

# Function for authentication setup
function Setup-Authentication($app, $sp) {
    $nativeClient = 'https://login.microsoftonline.com/common/oauth2/nativeclient'
    $liveSDK = 'https://login.live.com/oauth20_desktop.srf'
    $msalonly = 'msal'+$app.appId+'://auth'

    Set-AzureADMSApplication -ObjectId $app.Id -PublicClient @{RedirectUris = @("http://localhost", $msalonly, $liveSDK, $nativeClient)}

    Set-AzureADServicePrincipal -ObjectId $sp.Id -AppRoleAssignmentRequired $true
}

# Function for user and group assignment
function Assign-UserAndGroup($app, $sp) {
    # For each user email, get the user, then assign them to the application
    foreach ($userEmail in $userEmails) {
        $user = $user = Get-AzureADUser -ObjectId '$userEmail'"

        # Assign the user to the app role
        New-AzureADUserAppRoleAssignment -ObjectId $user.ObjectId -PrincipalId $user.ObjectId -ResourceId $sp.Id -Id $readersAppRoleId
    }

    $groupName = "${customerName}-octaipipe-users"
    $group = New-AzureADGroup -DisplayName $groupName -MailEnabled $false -SecurityEnabled $true -MailNickName "NotUsed" -Description "Group for OctaiPipe Users"

    # Add the Service Principal as the owner of the group
    Add-AzureADGroupOwner -ObjectId $group.ObjectId -RefObjectId $sp.Id

    # Create a new AppRoleAssignment for the group
    New-AzureADGroupAppRoleAssignment -ObjectId $group.ObjectId -PrincipalId $group.ObjectId -ResourceId $sp.Id -Id $readersAppRoleID

    return $group
}

# Add Client Secret for App
function Create-ClientSecret($app) {
    $secretStartDate = Get-Date
    $secretEndDate = $secretStartDate.AddYears(1)
    $servicePrincipalSecretObject = New-AzADAppCredential -StartDate $secretStartDate -EndDate $secretEndDate -ApplicationId $app.AppId 
    Write-Output $servicePrincipalSecretObject.SecretText
}

# Execution of the functions
Setup-AzureContext
$app, $sp = Create-AppAndSP
Setup-AppRoleAndPermissions $app $sp
Setup-Authentication $app $sp
$group = Assign-UserAndGroup $app $sp
$servicePrincipalSecret = Create-ClientSecret $app

# Assuming $app, $sp, and $group have the necessary properties
$clientId = $app.AppId
$azureAdGroupName = $group.DisplayName
$azureAdGroupId = $group.Id
$objectId = $app.Id

# Output the values
Write-Output $clientId
Write-Output $azureAdGroupName
Write-Output $azureAdGroupId
Write-Output $objectId
Write-Output $servicePrincipalSecret

$DeploymentScriptOutputs = @{
    'clientId' = $clientId
    'azureAdGroupName' = $azureAdGroupName
    'azureAdGroupId' = $azureAdGroupId
    'objectId' = $objectId
    'servicePrincipalSecret' = $servicePrincipalSecret
}

# Convert the hashtable to a clixml and write it to the predefined environment variable
$DeploymentScriptOutputs | ConvertTo-Clixml | Out-File $env:AZ_SCRIPTS_OUTPUT_PATH