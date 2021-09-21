# Configuring DocuWare to use Azure Service Bus

To use Azure Service Bus with DocuWare, you must configure all services to connect to an Azure Service Bus instance.
We provide a script, which does the configuration.

> *WARNING* This is the installation instruction for DocuWare 7.2. Do not apply this on other versions of DocuWare.

Please follow the steps in order to connect your DocuWare installation with Azure Service Bus:

## Create an Azure Service Bus namespace and get an access key

### Option 1: Create the namespace in the Azure Portal

You can create the namespace in the Azure Portal following the [Quickstart](https://docs.microsoft.com/en-us/azure/service-bus-messaging/service-bus-quickstart-topics-subscriptions-portal) tutorial. Ensure, that you select _Standard_ or _Premium_ as sku. A _Basic_ sku does not provide the
features which DocuWare needs.

If the Azure Service Bus is created, go to the Azure portal and create a shared access policy key. Choose a name like _docuware_ and give the rights _Manage_, _Send_ and _Listen_.

When the key is created, open it in the Portal and copy either the __Primary Connection String__ or the __Secondary Connection String__ string to the clipboard.

### Option 2: Use Azure CLI

You can use the Azure CLI to create the Azure Service Bus instance automatically, 
without the Azure Portal. If you do not have Azure CLI installed,
get it from [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows).

We provide a [script](./create-servicebus.ps1), which does all the necessary steps for you. Open the script in an editor and change the parameters according to your setup.
Then execute the following steps in either Powershell or Powershell Core:

```powershell
az login # Only needed if you are not logged in yet
.\create-servicebus.ps1
```

The script returns both the primary and secondary connection string.

## Connect DocuWare with the Azure Service Bus

Run the script [enable-azure-service-bus.ps1](enable-azure-service-bus.ps1) in Powershell or Powershell Core:

```powershell
.\enable-azure-service-bus.ps1
```

The script requests the connection string, which you obtained either from the Azure Portal or the Azure CLI. Alternatively, you can pass it as parameter to the script:

```powershell
.\enable-azure-service-bus.ps1 -connectionString "Endpoint=sb://peters-engineering-inst00.servicebus.windows.net/;SharedAccessKeyName=docuware;SharedAccessKey=..."
```

The script replaces the DocuWare MessageBus standard configuration with the connection to Azure Service Bus by replacing the settings in the configuration files of all DocuWare services. The original configuration is backed up, so that you can go back by replacing the configurations with the backup files.

After the script was run, you must restart all DocuWare services, e.g. by using the DocuWare Service Control.

You must repeat these steps on all virtual machines of your installation.

If you use Azure CLI and our script to create the Service Bus instance, you can combine the two steps of creating the Azure Service Bus instance and reconfiguring DocuWare within a single step:

```powershell
az login # Only needed if you are not logged in yet
.\enable-azure-service-bus.ps1 -connectionString (.\create-servicebus.ps1).primaryConnectionString
```

You can repeat this on all VMs of your installation. (The script _create-servicebus.ps1_ checks if the service bus exists already. In this case the service bus and the access key are reused.)

## Check the Service Bus connections

After DocuWare was reconfigured and the services were restarted, you should see new _topics_ in the Azure Service Bus blade. You should also see that the number of subscriptions raise.

If you do not see any topics or subscriptions created, check if your firewalls have the ports [configured to allow traffic](https://blogs.msdn.microsoft.com/servicebus/2017/11/07/open-port-requirements-and-ip-address-whitelisting/) between the VMs and Azure Service Bus.
