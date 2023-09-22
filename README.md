# OctaiPipe-ARM-Deployment

The file structure is configured to form a managed application offer i.e. includes:
- mainTemplate.json
- createUiDefinition.json

## Inputs
The mainTemplate takes the following inputs

- **customerName** - Name of the customer
- **subscriptionId** - Id of the users Azure subscription
- **tenantId** - Customer's tenant Id
- **userEmails** - Email addresses of users who will use OctaiPipe
- **sqlAdminLogin** - SQL admin username (can be hardcoded or set to the company name)
- **sqlAdminLoginPassword** - SQL password (Can use a random string for this to reduce number of inputs)

> [!NOTE]
> These values are currently hardcoded to testing values

The createUiDefinition.json file defines the landing page for the application, it is the page on which a user enters these inputs:
![image](https://github.com/OctaiPipe/OctaiPipe-ARM-Deployment/assets/110408564/6b040c70-f04a-42c5-ad54-66059e50b1f9)

## Structure
The OctaiPipe architecture (including sql server, web app etc) is defined in artifacts/linkedTemplate.json.

The mainTemplate:
- creates a managed identity
- assigns it a contributor role
- Runs the artifacts/AzureSPAppAndPermissionsSetup.ps1 deployment script
  - This sets up required azure AD features (app role, permissions, users, group etc.) all of which cannot be handled by ARM template
  - It is referred to by raw github link rather than relatively i.e. https://raw.githubusercontent.com/The-Data-Analysis-Bureau/OctaiPipe-ARM-Deployment/main/octaipipeTemplate/artifacts/AzureSPAppAndPermissionsSetup.ps1. So ensure that changes are pushed before attempt to run deployment locally.
- Runs the artifacts/linkedTemplate.json template with the outputs from the deployment script.
  - Also referred to by raw github link rather than relatively i.e. [https://raw.githubusercontent.com/The-Data-Analysis-Bureau/OctaiPipe-ARM-Deployment/main/octaipipeTemplate/artifacts/AzureSPAppAndPermissionsSetup.ps1](https://raw.githubusercontent.com/The-Data-Analysis-Bureau/OctaiPipe-ARM-Deployment/main/octaipipeTemplate/artifacts/linkedTemplate.json)https://raw.githubusercontent.com/The-Data-Analysis-Bureau/OctaiPipe-ARM-Deployment/main/octaipipeTemplate/artifacts/linkedTemplate.json. So ensure that changes are pushed before attempt to run deployment locally. 

## Run locally
- Install Azure CLI
- Run az login
- Either create a parameters file `octaipipeParams.json` or hard code in the mainTemplate paramaters section.
- Create resource group:
  - `az deployment group create --resource-group <YourResourceGroup> --template-file octaipipeTemplate/mainTemplate.json --parameters <parameters file if you've created one>`
