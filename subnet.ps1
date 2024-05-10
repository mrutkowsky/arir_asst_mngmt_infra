# Save resource group name and region as variables for convenience
groupName=myresourcegroup
region=eastus
az group create --name $groupName --location $region
# Save App Service plan name as a variable for convenience
aspName=<app-service-plan-name>
az appservice plan create --name $aspName --resource-group $groupName --is-linux --location $region --sku P1V3
az webapp create --name $frontendApp --resource-group $groupName --plan $aspName --runtime "NODE:18-lts"
az webapp create --name $backendApp --resource-group $groupName --plan $aspName --runtime "NODE:18-lts"

# Save vnet name as variable for convenience
vnetName=<virtual-network-name>
az network vnet create --resource-group $groupName --location $region --name $vnetName --address-prefixes 10.0.0.0/16
az network vnet subnet create --resource-group $groupName --vnet-name $vnetName --name vnet-integration-subnet --address-prefixes 10.0.0.0/24 --delegations Microsoft.Web/serverfarms --disable-private-endpoint-network-policies false
az network vnet subnet create --resource-group $groupName --vnet-name $vnetName --name private-endpoint-subnet --address-prefixes 10.0.1.0/24 --disable-private-endpoint-network-policies true
az network private-dns zone create --resource-group $groupName --name privatelink.azurewebsites.net
az network private-dns link vnet create --resource-group $groupName --name myDnsLink --zone-name privatelink.azurewebsites.net --virtual-network $vnetName --registration-enabled False
# Get backend web app resource ID
resourceId=$(az webapp show --resource-group $groupName --name $backendApp --query id --output tsv)
az network private-endpoint create --resource-group $groupName --name myPrivateEndpoint --location $region --connection-name myConnection --private-connection-resource-id $resourceId --group-id sites --vnet-name $vnetName --subnet private-endpoint-subnet
az network private-endpoint dns-zone-group create --resource-group $groupName --endpoint-name myPrivateEndpoint --name myZoneGroup --private-dns-zone privatelink.azurewebsites.net --zone-name privatelink.azurewebsites.net
az webapp vnet-integration add --resource-group $groupName --name $frontendApp --vnet $vnetName --subnet vnet-integration-subnet
az webapp update --resource-group $groupName --name $backendApp --set publicNetworkAccess=Enabled
az resource update --resource-group $groupName --name $backendApp --namespace Microsoft.Web --resource-type sites --set properties.siteConfig.ipSecurityRestrictionsDefaultAction=Deny
az resource update --resource-group $groupName --name $backendApp --namespace Microsoft.Web --resource-type sites --set properties.siteConfig.scmIpSecurityRestrictionsDefaultAction=Allow
az resource update --resource-group $groupName --name ftp --namespace Microsoft.Web --resource-type basicPublishingCredentialsPolicies --parent sites/$frontendApp --set properties.allow=false
az resource update --resource-group $groupName --name ftp --namespace Microsoft.Web --resource-type basicPublishingCredentialsPolicies --parent sites/$backendApp --set properties.allow=false
az resource update --resource-group $groupName --name scm --namespace Microsoft.Web --resource-type basicPublishingCredentialsPolicies --parent sites/$frontendApp --set properties.allow=false
az resource update --resource-group $groupName --name scm --namespace Microsoft.Web --resource-type basicPublishingCredentialsPolicies --parent sites/$backendApp --set properties.allow=false


az webapp ssh --resource-group $groupName --name $frontendApp