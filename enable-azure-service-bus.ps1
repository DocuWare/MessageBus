param(
    [Parameter(Mandatory = $true)]
    [string] $connectionString
)

[Reflection.Assembly]::LoadWithPartialName("System.Xml.Linq") | Out-Null

$files = @( 
    "C:\Program Files\DocuWare\Web\Platform\web.config"
    "C:\Program Files\DocuWare\Web\Settings\web.config",
    "C:\Program Files\DocuWare\Web\Processes\web.config",
    "C:\Program Files\DocuWare\Background Process Service\DocuWare.BackgroundProcessService.exe.config",
    "C:\Program Files\DocuWare\Background Process Service\DocuWare.BackgroundProcessService.LongLiving.GenericProcess.exe.config",
    "C:\Program Files\DocuWare\Background Process Service\DocuWare.BackgroundProcessService.LongLiving.GenericProcess.x86.exe.config",
    "C:\Program Files (x86)\DocuWare\Authentication Server\DWAuthenticationServer.exe.config"
    "C:\Program Files (x86)\DocuWare\Notification Server\DWNotificationServer.exe.config",
    "C:\Program Files (x86)\DocuWare\Workflow Server\DWWorkflowServer.exe.config"
)

$dlls = @(
    "Hyak.Common.dll",
    "MessagePack.Annotations", 
    "MessagePack", 
    "Microsoft.Azure.Amqp",
    "Microsoft.Azure.Common", 
    "Microsoft.Azure.ServiceBus", 
    "Newtonsoft.Json", 
    "Polly", 
    "System.Buffers",
    "System.Diagnostics.DiagnosticSource",
    "System.Memory",
    "System.Numerics.Vectors",
    "System.Runtime.CompilerServices.Unsafe",
    "System.Threading.Tasks.Dataflow",
    "System.Threading.Tasks.Extensions"
)

[string] $providers = "<Providers>
<add name='az' type='DocuWare.MessageBus.Azure.Provider.HyperBus, DocuWare.MessageBus.Azure.Provider' customConfigurationType='DocuWare.MessageBus.Azure.Provider.HyperBusConfiguration, DocuWare.MessageBus.Azure.Provider' connectionString='$connectionString' />
</Providers>"



[System.Xml.Linq.XNamespace] $asmNs = [System.Xml.Linq.XNamespace]::Get("urn:schemas-microsoft-com:asm.v1")

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

    # Patch the assembly binding redirects
    $runtimeElement = $xDoc.Root.Element("runtime");
    if (-not $runtimeElement) {
        $runtimeElement = [System.Xml.Linq.XElement]::new("runtime");
        $xDoc.Root.Add($runtimeElement);
    }

    $abName = [System.Xml.Linq.XName]::Get("assemblyBinding", $asmNs);
    $abElementName = [System.Xml.Linq.XName]::Get("assemblyIdentity", $asmNs)
    $daElementName = [System.Xml.Linq.XName]::Get("dependentAssembly", $asmNs)

    $abElement = $runtimeElement.Element($abName);
    if (-not $abElement) {
        $abElement = [System.Xml.Linq.XElement]::new($abName);
        $runtimeElement.Add($abElement);
    }

    $binDir = [System.IO.Path]::GetDirectoryName($file);
    if ($file.EndsWith("web.config")) {
        $binDir += '\bin'
    }

    foreach ($dll in $dlls) {
        [System.Xml.Linq.XElement] $match = $null;

        foreach ($el in $abElement.Elements($daElementName)) {
            if ($el.Element($abElementName).Attribute("name").Value -eq $dll) {
                $match = $el;
                break;
            }
        }

        if (-not $match) {
            $asmPath = [System.IO.Path]::Combine($binDir, "$($dll).dll")
            if (Test-Path $asmPath) {
                $assemblyName = [System.Reflection.Assembly]::LoadFile($asmPath).GetName();
                $publicKeyToken = $assemblyName.GetPublicKeyToken();
                [string] $publicKeyTokenString = "";
                foreach ($byte in $publicKeyToken) {
                    $publicKeyTokenString += $byte.ToString("x2");
                }

                $newAbEl = [System.Xml.Linq.XElement]::new($abElementName);
                $newAbEl.Add([System.Xml.Linq.XAttribute]::new("name", $dll));
                $newAbEl.Add([System.Xml.Linq.XAttribute]::new("publicKeyToken", $publicKeyTokenString));

                $newDaEl = [System.Xml.Linq.XElement]::new($daElementName);
                $newDaEl.Add($newAbEl);

                $version = $assemblyName.Version.ToString()

                $brElement = [System.Xml.Linq.XElement]::new([System.Xml.Linq.XName]::Get("bindingRedirect", $asmNs));
                $brElement.Add([System.Xml.Linq.XAttribute]::new("oldVersion", "0.0.0.0-255.255.255.255"));
                $brElement.Add([System.Xml.Linq.XAttribute]::new("newVersion", $version));
                $newDaEl.Add($brElement);

                $abElement.Add($newDaEl);
                Write-Host "Added assembly binding redirect for $dll"
            }
        }
    }

    $xDoc.Save("$file");
}