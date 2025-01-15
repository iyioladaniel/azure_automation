# Input parameters
param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "subscriptionID",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rgName",
    
    [Parameter(Mandatory=$false)]
    [string]$VMName = "VMName",
    
    [Parameter(Mandatory=$false)]
    [int]$StartHour = 8    # 8 AM UTC
)

# Function to check if it's a weekend (Saturday or Sunday)
function Test-Weekend {
    $currentTime = (Get-Date).ToUniversalTime().AddHours(1) # Ensure UTC +1 time is used
    $isWeekend = $currentTime.DayOfWeek -in @('Saturday', 'Sunday')
    
    if ($isWeekend) {
        Write-Host "Current day is weekend. VM will not be started."
        return $true
    }
    
    return $false
}

# Function to check if it's the scheduled start time (8 AM UTC)
function Test-StartTime {
    $currentTime = (Get-Date).ToUniversalTime().AddHours(1) # Ensure UTC +1 time is used
    $currentHour = $currentTime.Hour
    
    if ($currentHour -eq $StartHour -or $currentHour -ge $StartHour) {
        Write-Host "Current time is $StartHour:00 UTC+1. VM should be started."
        return $true
    }
    
    Write-Host "Current time is not $StartHour:00 UTC+1. No action taken."
    return $false
}

try {
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
    
    # Check if it's a weekend and if it's time to start the VM
    $isWeekend = Test-Weekend
    $isStartTime = Test-StartTime

    Write-Output "isWeekend: $isWeekend and isStartTime: $isStartTime"

    if (-not $isWeekend -and $isStartTime) {
        # If not weekend and it's the correct time, start the VM
        if ($vmStatus.DisplayStatus -ne "VM running") {
            Write-Output "VM is not running. Starting VM..."
            #$startResult = Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
            
            if ($startResult.Status -eq "Succeeded") {
                Write-Output "VM start initiated successfully."
            } else {
                throw "VM start failed with status: $($startResult.Status)"
            }
        } else {
            Write-Output "VM is already running. No action taken."
        }
    }
}
catch {
    Write-Error "An error occurred: $_"
    throw $_
}

