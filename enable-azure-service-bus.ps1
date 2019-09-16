param(
    [Parameter(Mandatory=$true)]
    [string] $connectionString
)

[Reflection.Assembly]::LoadWithPartialName("System.Xml.Linq") | Out-Null

$files = @( 
    "C:\Program Files\DocuWare\Web\Platform\web.config",
    "C:\Program Files\DocuWare\Web\Settings\web.config",
    "C:\Program Files\DocuWare\Web\Processes\web.config",
    "C:\Program Files\DocuWare\Background Process Service\DocuWare.BackgroundProcessService.exe.config",
    "C:\Program Files\DocuWare\Background Process Service\DocuWare.BackgroundProcessService.LongLiving.GenericProcess.exe.config",
    "C:\Program Files\DocuWare\Background Process Service\DocuWare.BackgroundProcessService.LongLiving.GenericProcess.x86.exe.config",
    "C:\Program Files (x86)\DocuWare\Authentication Server\DWAuthenticationServer.exe.config",
    "C:\Program Files (x86)\DocuWare\Notification Server\DWNotificationServer.exe.config",
    "C:\Program Files (x86)\DocuWare\Workflow Server\DWWorkflowServer.exe.config"
)

[string] $providers = "<Providers>
<add name='az' type='DocuWare.MessageBus.Azure.Provider.HyperBus, DocuWare.MessageBus.Azure.Provider' customConfigurationType='DocuWare.MessageBus.Azure.Provider.HyperBusConfiguration, DocuWare.MessageBus.Azure.Provider' connectionString='$connectionString' />
</Providers>"


foreach ($file in $files) {
    $backupFile = "$($file).$((Get-Date).ToString("yyyyMMddHHmmss"))";
    Write-Host "Backup '$file' -> '$backupFile'"
    Copy-Item $file $backupFile
    [System.Xml.Linq.XDocument] $xDoc = [System.Xml.Linq.XDocument]::Load($file)

    foreach ($el in $xDoc.Root.Descendants("HyperBusFactory")) {
        [System.Xml.Linq.XElement] $h = $el;
        $h.RemoveAll();
        $h.SetAttributeValue("selectedProvider", "az")
        $h.Add([System.Xml.Linq.XElement]::Parse($providers));
    }

    $xDoc.Save("$file");
}