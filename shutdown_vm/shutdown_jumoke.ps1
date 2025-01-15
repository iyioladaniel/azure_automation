# Input parameters
param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "subscriptionID",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rgName",
    
    [Parameter(Mandatory=$false)]
    [string]$VMName = "VMName",
    
    [Parameter(Mandatory=$false)]
    [int]$WorkdayStartHour = 8,  # 8 AM UTC+1
    
    [Parameter(Mandatory=$false)]
    [int]$WorkdayEndHour = 18    # 6 PM UTC+1
)

# Connect using managed identity
Write-Output "Connecting to Azure using Managed Identity..."
$connection = Connect-AzAccount -Identity

if (-not $connection) {
    throw "Failed to connect using Managed Identity"
}

Write-Output "Successfully connected using Managed Identity"

# Validate subscription exists and is accessible
$subscription = Get-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue
if (-not $subscription) {
    throw "Subscription ID '$SubscriptionId' not found or not accessible"
}

# Set the correct subscription
Write-Output "Setting subscription context to '$SubscriptionId'..."
$context = Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop
if (-not $context) {
    throw "Failed to set subscription context"
}
Write-Output "Successfully set subscription context"

# Validate resource group exists
$resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $resourceGroup) {
    throw "Resource group '$ResourceGroupName' not found in subscription '$SubscriptionId'"
}

# Get VM status with validation
Write-Output "Checking VM '$VMName' in resource group '$ResourceGroupName'..."
$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
if (-not $vm) {
    throw "VM '$VMName' not found in resource group '$ResourceGroupName'"
}

$vmStatus = (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status).Statuses | 
    Where-Object { $_.Code -match "PowerState" }

Write-Output "Current VM status: $($vmStatus.DisplayStatus)"


# Get the current time in UTC

$currentTimeUTC = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
 
# Get the current day of the week (0 = Sunday, 6 = Saturday)

$currentDay = (Get-Date).DayOfWeek
 
# Check if today is a weekend (Saturday or Sunday)

$isWeekend = ($currentDay -eq 'Saturday' -or $currentDay -eq 'Sunday')
 
# If it's weekend, shut down the VM regardless of time

if ($isWeekend) {

    Write-Output "It's the weekend. Shutting down the VM..."
 
    # Shut down the VM

    #Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Force

} 

# If it's a weekday and it's after work hours, shut down the VM

elseif ($currentTimeUTC -ge $utcWorkEnd) {

    Write-Output "It's after work hours. Shutting down the VM..."
 
    # Shut down the VM

    #Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Force

} else {

    Write-Output "It's within work hours or a weekday. No action taken."

}
 