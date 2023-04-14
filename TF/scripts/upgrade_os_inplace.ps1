param (
    [Parameter(Mandatory = $true)]
    [string]$JsonString
)

Update-Module Az -Force

$json = ConvertFrom-Json $JsonString

Write-Output "Processing the following items:"
Write-Output $json

# running locally, do not need this secret section

## $tenantId = $env:ARM_TENANT_ID
## $clientId = $env:ARM_CLIENT_ID
## $secret = $env:ARM_CLIENT_SECRET
## 
## $securesecret = ConvertTo-SecureString -String $secret -AsPlainText -Force
## $Credential = New-Object pscredential($clientId, $securesecret)
## Connect-AzAccount -Credential $Credential -Tenant $tenantId -ServicePrincipal

#Get Vm Details
foreach ($virtualMachine in $json) {
    Select-AzSubscription $virtualMachine.subscription_id
    $virtualMachineObject = Get-AzVM -Name $virtualMachine.virtual_machine_name
    if (!$virtualMachineObject) { "Vm not grabbed"; break; }

    # Validate Current vm OS is suitable for upgrade
    $currentOS = (Invoke-AzVMRunCommand -ResourceGroupName $virtualMachineObject.resourceGroupName  -Name $virtualMachineObject.Name  -CommandId 'RunPowerShellScript' -ScriptString '$osinfo = (Get-WMIObject win32_operatingsystem); Write-Output $osinfo.Caption').Value[0].Message

    if ($currentOS -like "Microsoft Windows Server 2012 R2*") { "Proceeding with Upgrade as OS is 2012R2" }else { "Halting Upgrade as OS is not 2012R2"; break; }
    #Ensure disks are all managed
    foreach ($disk in $virtualMachineObject.StorageProfile.DataDisks) {
        if (!$disk.ManagedDisk) {
            Write-Output "Unmanaged disk detected on $($virtualMachineObject.Name)"
            break;
        }

        #Snapshot Data Disks
        $snapshot = New-AzSnapshotConfig `
            -SourceUri $disk.ManagedDisk.Id `
            -Location $virtualMachineObject.location `
            -CreateOption copy

        $results = New-AzSnapshot `
            -Snapshot $snapshot `
            -SnapshotName "$($disk.Name)-snapshot-$(Get-Date -format "dd-MMM-yyyy-HH-mm")" `
            -ResourceGroupName $virtualMachineObject.resourceGroupName 

    }

    #Snapshot OS Disk
    $snapshot = New-AzSnapshotConfig `
        -SourceUri $virtualMachineObject.StorageProfile.OsDisk.ManagedDisk.Id `
        -Location $virtualMachineObject.location `
        -CreateOption copy
    
    $results = New-AzSnapshot `
        -Snapshot $snapshot `
        -SnapshotName "$($virtualMachineObject.Name)-os-snapshot-$(Get-Date -format "dd-MMM-yyyy-HH-mm")" `
        -ResourceGroupName $virtualMachineObject.resourceGroupName 

    # Resource group of the source VM
    $resourceGroup = $virtualMachineObject.resourceGroupName 

    # Location of the source VM
    $location = $virtualMachineObject.location

    # Zone of the source VM, if any
    $zone = $virtualMachineObject.Zones

    # Disk name for the that will be created
    $diskName = "$($virtualMachineObject.name)-upgradedisk"

    # Target version for the upgrade - must be either server2022Upgrade or server2019Upgrade
    $sku = "server2019Upgrade"

    # Common parameters
    $publisher = "MicrosoftWindowsServer"
    $offer = "WindowsServerUpgrade"
    $managedDiskSKU = "Standard_LRS"

    # Get the latest version of the special (hidden) VM Image from the Azure Marketplace
    $versions = Get-AzVMImage -PublisherName $publisher -Location $location -Offer $offer -Skus $sku | sort-object -Descending { [version] $_.Version	}
    $latestString = $versions[0].Version

    # Get the special (hidden) VM Image from the Azure Marketplace by version - the image is used to create a disk to upgrade to the new version
    $image = Get-AzVMImage -Location $location `
        -PublisherName $publisher `
        -Offer $offer `
        -Skus $sku `
        -Version $latestString

    # Create Managed Disk from LUN 0

    if ($zone) {
        $diskConfig = New-AzDiskConfig -SkuName $managedDiskSKU `
            -CreateOption FromImage `
            -Zone $zone `
            -Location $location
    }
    else {
        $diskConfig = New-AzDiskConfig -SkuName $managedDiskSKU `
            -CreateOption FromImage `
            -Location $location
    }

    $results = Set-AzDiskImageReference -Disk $diskConfig -Id $image.Id -Lun 0

    $dataDisk1 = New-AzDisk -ResourceGroupName $virtualMachineObject.ResourceGroupName`
        -DiskName $diskName `
        -Disk $diskConfig

    [int]$lun = $virtualMachineObject.StorageProfile.DataDisks[-1].Lun + 1

    $results = Add-AzVMDataDisk -VM $virtualMachineObject -Name $diskName -CreateOption Attach -ManagedDiskId $dataDisk1.Id -Lun $lun

    $results = Update-AzVM -VM $virtualMachineObject -ResourceGroupName $virtualMachineObject.ResourceGroupName

    $script = @'
    $drive = (Get-volume | where {$_.FileSystemLabel -eq "upgrade"}).DriveLetter + ":\"
    cd $drive"\Windows Server 2019"
    .\setup.exe /auto upgrade /dynamicupdate disable /imageindex 4 /quiet
'@

    Invoke-AzVMRunCommand -ResourceGroupName $virtualMachineObject.ResourceGroupName -Name $virtualMachineObject.Name -CommandId 'RunPowerShellScript' -ScriptString $script
}
