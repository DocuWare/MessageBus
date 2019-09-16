# This script needs the Azue CLI tool installed.
# Get it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest


# Enter the name of the subscription. You can use the subscription of your Azure VMs.
[string] $subscription = "DocuWare Cloud Test"

# Enter the location where the service bus is hosted. It should be the same like for your Azure VMs.
[string] $location = "West Europe"

# Enter the name of the resource group. This could be the same like for your Azure VMs.
[string] $rg = "peters-engineering-inst00"

# Enter the name of the service bus. This is a globally unique name. Avoid special characters except “-“.
# The name must start with a letter and must not end with  “-“, “-sb“ or “-mgmt“.
# Example: peters-engineering-inst00. See https://docs.microsoft.com/en-us/rest/api/servicebus/create-namespace
[string] $namespace = "peters-engineering-inst00" 


# The default values are ok. Modify them only if needed.
[string] $serviceBusSku = "Standard" # Use Standard or Premium only
[string] $sharedAccessKeyName = "docuware"



$capture = (az account set --subscription $subscription)

[bool] $doesResourceGroupExist = [System.Boolean]::Parse($(az group exists --name $rg))
if(!$doesResourceGroupExist)
{
    $capture = (az group create --name $rg --location $location)
}


[bool] $nsAvailable = [System.Boolean]::Parse($(az servicebus namespace exists --name $namespace --query nameAvailable))
if($nsAvailable)
{
    $capture = (az servicebus namespace create --resource-group $rg --name $namespace --sku $serviceBusSku)
}

$capture = (az servicebus namespace authorization-rule create --resource-group $rg --namespace-name $namespace --name $sharedAccessKeyName --rights Manage Send Listen)
$keys = (az servicebus namespace authorization-rule keys list --resource-group $rg --namespace-name $namespace --name $sharedAccessKeyName -o json)

ConvertFrom-Json ($keys | Out-String)
