[CmdletBinding()]
param (
    # RG name containing the CMES VMSS
    [Parameter(mandatory = $true)]
    [string]
    $ResourceGroupName,

    # Name of the CMES VMSS
    [Parameter(mandatory = $true)]
    [string]
    $CmesVmssName,

    # The desired CMES version
    [Parameter(mandatory = $true)]
    [string]
    [ValidateScript({$_ -ne "latest"}, ErrorMessage = "A specific version must be used, do not specify 'latest' as the version.")]
    $CmesImageVersion,

    # Optional, the desired number of instances.
    # If not specified, then the VMSS will return to its current number of instances
    [Parameter(mandatory = $false)]
    [int]
    $DesiredNumberOfInstances,

    # Optional, delay to allow nay data migration to finish before scaling up to the VMSS to the required number of instances
    [Parameter(mandatory = $false)]
    [int]
    $DataMigrationDelay = 45
)

#Requires -Version 6.0
#Requires -Modules Az.Compute

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

if ($PSBoundParameters.ContainsKey('DesiredNumberOfInstances') -eq $false) {
    # the "DesiredNumberOfInstances" parameter was not specified, get the current number of instances

    Write-Information "Getting current number of instance VMs."

    $vmss = Get-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $CmesVmssName

    $DesiredNumberOfInstances = $vmss.Sku.Capacity

    Write-Information "The CMES VMSS currently has $DesiredNumberOfInstances instance VMs."
}

Write-Information "Scaling in to 0 instances."

Update-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $CmesVmssName -SkuCapacity 0 | Out-Null

Write-Information "Updating the VMSS to use CMES image version $CmesImageVersion."

Update-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $CmesVmssName -ImageReferenceVersion $CmesImageVersion | Out-Null

Write-Information "Scaling out to 1 instance."

Update-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $CmesVmssName -SkuCapacity 1 | Out-Null

Write-Information "Waiting for $DataMigrationDelay seconds to allow the data migration process to finish."

Start-Sleep -Seconds $DataMigrationDelay

if ($DesiredNumberOfInstances -gt 1) {
    Write-Information "Scaling out to $DesiredNumberOfInstances instances."

    Update-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $CmesVmssName -SkuCapacity $DesiredNumberOfInstances | Out-Null
}

Write-Information "Version update process is complete."

