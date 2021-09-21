param(
    [Parameter(Mandatory = $true)]
    [string] $connectionString
)

[Reflection.Assembly]::LoadWithPartialName("System.Xml.Linq") | Out-Null

[System.Xml.Linq.Xname] $rt = [System.Xml.Linq.Xname]::Get("runtime")
[System.Xml.Linq.Xname] $ab = [System.Xml.Linq.Xname]::Get("assemblyBinding", "urn:schemas-microsoft-com:asm.v1")
[System.Xml.Linq.Xname] $da = [System.Xml.Linq.Xname]::Get("dependentAssembly", "urn:schemas-microsoft-com:asm.v1")
[System.Xml.Linq.Xname] $ai = [System.Xml.Linq.Xname]::Get("assemblyIdentity", "urn:schemas-microsoft-com:asm.v1")
[System.Xml.Linq.Xname] $br = [System.Xml.Linq.Xname]::Get("bindingRedirect", "urn:schemas-microsoft-com:asm.v1")



$files = @( 
    "C:\Program Files\DocuWare\Background Process Service\DocuWare.BackgroundProcessService.exe.config",
    "C:\Program Files\DocuWare\Background Process Service\DocuWare.BackgroundProcessService.LongLiving.GenericProcess.exe.config",
    "C:\Program Files\DocuWare\Background Process Service\DocuWare.BackgroundProcessService.LongLiving.GenericProcess.x86.exe.config",
    "C:\Program Files\DocuWare\Web\DocCap\Web.config",
    "C:\Program Files\DocuWare\Web\FormsService\Web.config",
    "C:\Program Files\DocuWare\Web\Platform\Web.config",
    "C:\Program Files\DocuWare\Web\Processes\Web.config",
    "C:\Program Files\DocuWare\Web\SearchService\Web.config",
    "C:\Program Files\DocuWare\Web\Settings\Web.config",
    "C:\Program Files (x86)\DocuWare\Authentication Server\DWAuthenticationServer.exe.config",
    "C:\Program Files (x86)\DocuWare\Setup Components\Templating\DocuWare.Templating.Console.exe.config",
    "C:\Program Files (x86)\DocuWare\Workflow Server\DWWorkflowServer.exe.config"
)

[string] $providers = "<Providers>
<add name='az' type='DocuWare.MessageBus.Azure.Provider.HyperBus, DocuWare.MessageBus.Azure.Provider' customConfigurationType='DocuWare.MessageBus.Azure.Provider.HyperBusConfiguration, DocuWare.MessageBus.Azure.Provider' connectionString='$connectionString' />
</Providers>"

$filesToCheck = @(
    "System.Memory.dll",
    "System.Runtime.CompilerServices.Unsafe.dll",
    "System.Diagnostics.DiagnosticSource.dll",
    "Newtonsoft.Json.dll"
)

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

    foreach ($assemblyFileName in $filesToCheck) {
        foreach ($assemblyFilePart in @($assemblyFileName, "bin\$assemblyFileName")) {
            $assemblyFile = Join-Path (Split-Path $file) $assemblyFilePart
            #Write-Host $assemblyFile
            if (Test-Path $assemblyFile -PathType Leaf) {
                $asm = [System.Reflection.Assembly]::LoadFile($assemblyFile)
                #Write-Host $asm.FullName
                $isMatch = $asm.FullName -match '^(.+), Version=(.+), Culture=(.+), PublicKeyToken=(.+)$'
                $myMatches = $Matches;

                $runtime = $xDoc.Root.Element($rt);
                if (-not $runtime) {
                    $runtime = New-Object System.Xml.Linq.XElement $rt
                    $xDoc.Root.Add($runtime);
                }

                $assemblyBindings = $runtime.Element($ab);
                if (!$assemblyBindings) {
                    $assemblyBindings = New-Object System.Xml.Linq.XElement $ab
                    $runtime.Add($assemblyBindings);
                }

                $bindingRedirect = $null;
                foreach ($daElement in $assemblyBindings.Elements($da)) {
                    $aiElement = $daElement.Element($ai);
                    if ($aiElement -and $aiElement.Attribute("name").Value -eq $myMatches[1]) {
                        $bindingRedirect = $daElement.Element($br);
                        break;
                    }
                }

                $newVersion = $myMatches[2];

                if (-not $bindingRedirect) {
                    $daElement = New-Object System.Xml.Linq.XElement $da
                    $assemblyBindings.Add($daElement)

                    $aiElement = New-Object System.Xml.Linq.XElement $ai
                    $aiElement.SetAttributeValue("name", $myMatches[1]);
                    $aiElement.SetAttributeValue("publicKeyToken", $myMatches[4]);
                    $aiElement.SetAttributeValue("culture", $myMatches[3]);

                    $daElement.Add($aiElement);

                    $bindingRedirect = New-Object System.Xml.Linq.XElement $br
                    $daElement.Add($bindingRedirect);
                }

                $bindingRedirect.SetAttributeValue("oldVersion", "0.0.0.0-255.255.255.255");
                $bindingRedirect.SetAttributeValue("newVersion", $newVersion);

                # Write-Host $bindingRedirect.Parent
            }
        }
    }

    $xDoc.Save("$file");
}