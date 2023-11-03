# OctaiPipe-ARM-Deployment

The file structure is configured to form a managed application offer i.e. includes:
- mainTemplate.json
- createUiDefinition.json

[Confluence page on using the deployment mechanism](https://octaipipe.atlassian.net/wiki/spaces/CAAS/pages/1305477121/Deploying+OctaiPipe+Via+Marketplace+Preview)

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
- `az deployment group create --resource-group <YourResourceGroup> --template-file octaipipeTemplate/mainTemplate.json --parameters <parameters file if you've created one>`
