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

# Function to check if current time is outside working hours
function Test-OutsideWorkingHours {
    $currentTime = (Get-Date).ToUniversalTime().AddHours(1) # Ensure UTC+1 i.e. West African Time is used
    $currentHour = $currentTime.Hour
    $isWeekend = $currentTime.DayOfWeek -in @('Saturday', 'Sunday')
    
    # Shut down if it's a weekend
    if ($isWeekend) {
        Write-Output "Current day is weekend. VM should be shutdown."
        return $true
    }

    # Shut down if before WorkdayStartHour or after WorkdayEndHour
    if ($currentHour -lt $WorkdayStartHour -or $currentHour -ge $WorkdayEndHour) {
        Write-Output "Current time is outside working hours. VM should be shutdown."
        return $true
    }
    
    # Otherwise, VM is within working hours
    Write-Output "Current time is within working hours. VM should remain running."
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

    # Check if VM is running and if it's outside working hours
    if ($vmStatus.DisplayStatus -eq "VM running") {
        $isOutsideWorkingHours = Test-OutsideWorkingHours

        if ($isOutsideWorkingHours) {
            Write-Output "Initiating VM shutdown..."
            $shutdownResult = Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force
            
            if ($shutdownResult.Status -eq "Succeeded") {
                Write-Output "VM shutdown completed successfully"
            } else {
                throw "VM shutdown failed with status: $($shutdownResult.Status)"
            }
        } else {
            Write-Output "VM is within working hours. No action taken."
        }
    } else {
        Write-Output "VM is not running. No action needed."
    }
}
catch {
    Write-Error "An error occurred: $_"
    throw $_
}

