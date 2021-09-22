param(
    [Parameter(Mandatory = $true)]
    [string] $connectionString
)

[System.Reflection.Assembly]::LoadWithPartialName("System.Xml.Linq") | Out-Null

[System.Xml.Linq.Xname] $rt = [System.Xml.Linq.Xname]::Get("runtime")
[System.Xml.Linq.Xname] $ab = [System.Xml.Linq.Xname]::Get("assemblyBinding", "urn:schemas-microsoft-com:asm.v1")
[System.Xml.Linq.Xname] $da = [System.Xml.Linq.Xname]::Get("dependentAssembly", "urn:schemas-microsoft-com:asm.v1")
[System.Xml.Linq.Xname] $ai = [System.Xml.Linq.Xname]::Get("assemblyIdentity", "urn:schemas-microsoft-com:asm.v1")
[System.Xml.Linq.Xname] $br = [System.Xml.Linq.Xname]::Get("bindingRedirect", "urn:schemas-microsoft-com:asm.v1")

$possibleConfigFiles = Get-ChildItem -Path "C:\*\DocuWare\*\*.config" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }

$files = @()

foreach ($possibleConfigFile in $possibleConfigFiles) {
    if (-not (Select-String -Path $possibleConfigFile -Pattern "HyperBusFactory")) {
        continue
    }
    [System.Xml.Linq.XDocument] $xDocument = [System.Xml.Linq.XDocument]::Load($possibleConfigFile)
    if (-not $xDocument) {
        continue
    }
    [System.Xml.Linq.XElement] $xElement = $xDocument.Root.Element("HyperBusFactory")
    if (-not $xElement) {
        continue
    }
    [System.Xml.Linq.XAttribute] $xAttribute = $xElement.Attribute("selectedProvider")
    if ((-not $xAttribute) -or ($xAttribute.Value -ne "MSMQ")) {
        continue
    }
    $files += $possibleConfigFile
}

[string] $providers = "<Providers>
<add name='az' type='DocuWare.MessageBus.Azure.Provider.HyperBus, DocuWare.MessageBus.Azure.Provider' customConfigurationType='DocuWare.MessageBus.Azure.Provider.HyperBusConfiguration, DocuWare.MessageBus.Azure.Provider' connectionString='$connectionString' />
</Providers>"
$startingAssembly = "DocuWare.MessageBus.Azure.Provider.dll"

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

    $baseDir = Split-Path -Path $file
    $startingAssemblyFile = Join-Path $baseDir $startingAssembly
    if (-not (Test-Path $startingAssemblyFile -PathType Leaf)) {
        $baseDir = Join-Path $baseDir "bin"
        $startingAssemblyFile = Join-Path $baseDir $startingAssembly
        if (-not (Test-Path $startingAssemblyFile -PathType Leaf)) {
            continue
        }
    }
    $assembliesToCheck = @($startingAssembly)
    $checkedAssemblies = @()
    $foundAssemblies = @()
    $neededAssemblyFullNames = @()
    $foundAssemblyFullNames = @()

    while ($assembliesToCheck.Count -gt 0) {
        $assemblyToCheck = $assembliesToCheck[0]
        $checkedAssemblies += $assemblyToCheck
        $assembliesToCheck = $assembliesToCheck[1..$assembliesToCheck.Length]

        $assemblyFileToCheck = Join-Path $baseDir $assemblyToCheck
        if (-not (Test-Path $assemblyFileToCheck)) {
            continue
        }

        [System.Reflection.Assembly] $assemblyObject = [System.Reflection.Assembly]::LoadFile($assemblyFileToCheck)
        [System.Reflection.AssemblyName] $assemblyName = $assemblyObject.GetName()
        [System.Reflection.AssemblyName[]] $referencedAssemblyNames = $assemblyObject.GetReferencedAssemblies()
        $foundAssemblies += $assemblyName.Name
        $foundAssemblyFullNames += $assemblyName.FullName
        foreach ($referencedAssemblyName in $referencedAssemblyNames) {
            $referencedAssembly = $referencedAssemblyName.Name + ".dll"
            if (($checkedAssemblies -notcontains $referencedAssembly) -and ($assembliesToCheck -notcontains $referencedAssembly)) {
                $assembliesToCheck += $referencedAssembly
            }
            if ($neededAssemblyFullNames -notcontains $referencedAssemblyName.FullName) {
                $neededAssemblyFullNames += $referencedAssemblyName.FullName
            }
        }
    }

    $assembliesToFix = @()

    for ($index = 0; $index -lt $foundAssemblies.Count; ++$index) {
        $foundAssembly = $foundAssemblies[$index]
        $foundAssemblyFullName = $foundAssemblyFullNames[$index]
        $tempArrayOrString = ($neededAssemblyFullNames | Where-Object { $_ -like ($foundAssembly + ",*") })
        if ($tempArrayOrString.Count -lt 1) {
            continue
        }
        if ($tempArrayOrString.Count -gt 1) {
            $assembliesToFix += $foundAssemblyFullName
            continue
        }
        if ($tempArrayOrString -ne $foundAssemblyFullName) {
            $assembliesToFix += $foundAssemblyFullName
        }
    }

    foreach ($assemblyToFix in $assembliesToFix) {
        #Write-Host $assemblyToFix
        $isMatch = $assemblyToFix -match '^(.+), Version=(.+), Culture=(.+), PublicKeyToken=(.+)$'
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

    $xDoc.Save("$file");
}