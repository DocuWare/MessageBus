# This script needs the Azure CLI tool installed.
# Get it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest

param(
    # Enter the name of the subscription. You can use the subscription of your Azure VMs.
    [string] $subscription = "My subscription",

    # Enter the location where the service bus is hosted. It should be the same like for your Azure VMs.
    [string] $location = "West Europe",

    # Enter the name of the resource group. This could be the same like for your Azure VMs.
    [string] $rg = "my-resource-group",

    # Enter the name of the service bus. This is a globally unique name. Avoid special characters except “-“.
    # The name must start with a letter and cannot end with “-“, “-sb“ or “-mgmt“.
    # Example: peters-engineering-inst00. See https://docs.microsoft.com/en-us/rest/api/servicebus/create-namespace
    [string] $namespace = "peters-engineering-inst00",

    # The default value is ok. Modify it only if needed. Use Standard or Premium only.
    [string] $serviceBusSku = "Standard",

    # The default value is ok. Modify it only if needed.
    [string] $sharedAccessKeyName = "docuware"
)

az account set --subscription $subscription
$currentSubscription = az account show | ConvertFrom-Json
if ((-not $currentSubscription) -or ($currentSubscription.name -ne $subscription)) {
    Write-Error "You are not logged in or your subscription name is wrong"
    return
}

[bool] $resourceGroupExists = [System.Boolean]::Parse($(az group exists --name $rg))
if (!$resourceGroupExists) {
    $createdResourceGroup = (az group create --name $rg --location $location)
    if (-not $createdResourceGroup) {
        Write-Error "Location or resource group name is wrong"
        return
    }
}

[bool] $namespaceAvailable = [System.Boolean]::Parse($(az servicebus namespace exists --name $namespace --query nameAvailable))
if (!$namespaceAvailable) {
    Write-Error "Service bus namespace is wrong"
    return
}

$serviceBus = az servicebus namespace create --resource-group $rg --name $namespace --sku $serviceBusSku
if (-not $serviceBus) {
    Write-Error "Service bus SKU is wrong"
    return
}

$createdRule = az servicebus namespace authorization-rule create --resource-group $rg --namespace-name $namespace --name $sharedAccessKeyName --rights Manage Send Listen
if (-not $createdRule) {
    Write-Error "Shared access key name is wrong"
    return
}

$keys = az servicebus namespace authorization-rule keys list --resource-group $rg --namespace-name $namespace --name $sharedAccessKeyName | ConvertFrom-Json
Write-Host ("primaryConnectionString: " + $keys.primaryConnectionString)
Write-Host ("secondaryConnectionString: " + $keys.secondaryConnectionString)
