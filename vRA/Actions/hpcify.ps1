function handler($context, $inputs) {
    
    # Make connections
    $user = $context.getSecret($inputs.uservra)
    $password = $context.getSecret($inputs.passwordvra)
    $vc =  $context.getSecret($inputs.vcenter)
    Connect-VIServer $vc -User $user -Password $password -Force
    $token = $context.getSecret($inputs.tokenvra)

    Connect-VRAserver -server "api.mgmt.cloud.vmware.com" -APIToken $token

    # Find the VMs in the deployment
    $deploymentid = $inputs.deploymentId
    $vmlist = (Invoke-vRARestMethod -Method GET -URI "/iaas/api/machines?`$filter=deploymentId%20eq%20'$deploymentid'").content
    try {
        $vms = get-vm -name $vmlist.name | Where-Object { $_.ExtensionData.config.LatencySensitivity.level -ne 'high' }
    }
    catch {
        Write-Error "Could not find any VMs to modify" -ErrorAction Stop
    }
    
    if (!$vms){
        exit
    }

    # Set CPU Reservation Variable
    $cpures = switch ($vms[0].numcpu) {
        44 { "105336" }
        52 { "134836" }
        60 {"156913"}
        8 { "20744" }
    }
    # Find the HPC PortGroup
    $hpcnic = $vms[0] | Get-NetworkAdapter | Where-Object -Property "NetworkName" -like "HPC*"
    $hpcnet = $hpcnic.NetworkName
    $hpcpg = Get-VDPortgroup -Name $hpcnet
    
    # Find the Scratch Space
    $scratchGB = $inputs.requestInputs.hpcProperties.scratchSpace
    if ($scratchGB){
        Write-host "Scratch space is $scratchGB"
    }
    

    # Move the VMs
    $vms | Foreach-object -Parallel {
        #Stop VM
        $_ | Stop-VM -confirm:$false
        
        # HPCify all VMs
        
        # Add scratch disk to the VM
        $vmname = $_.name
        if (($using:scratchGB) -and ($using:scratchGB -ne 0)){
            $ds = $_ | get-datastore -Name "*vsan*"
            $_ | New-HardDisk -CapacityGB $using:scratchGB -StorageFormat Thick -datastore $ds
        }

        # Set Cores per socket and reservations
        $_ | Set-VM -corespersocket ($_.numcpu / 4) -Confirm:$false
        $_ | Get-VMResourceConfiguration | Set-VMResourceConfiguration -MemReservationMB $_.MemoryMB -CpuReservationMhz $using:cpures
    
        # Set Latency Sensitivity to high
        $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
        $spec.latencySensitivity = New-Object VMware.Vim.LatencySensitivity
        $spec.LatencySensitivity.Level = [VMware.Vim.LatencySensitivitySensitivityLevel]::high
        $_.ExtensionData.ReconfigVM($spec)
    
        #Remove hpc net, add back with sriov card
        # This lets us use vRA to set the IP address but there's no way in vRA to set the nic type
        $hpcnic = $_ | Get-NetworkAdapter | Where-Object -Property "NetworkName" -like "HPC*"
        $hpcnic | Remove-NetworkAdapter -Confirm:$false
        $_ | New-NetworkAdapter -Type SriovEthernetCard -Portgroup $using:hpcpg  -macaddress $hpcnic.macaddress
        
        # Special rule for login nodes
        if ($_.numcpu -eq 8) {
            $vmhost = $_ | get-cluster | Get-VMHost -Tag "GP_8_16" | Sort-Object -Property MemoryUsageGB | select -First 1
            Move-VM -VM $_ -Destination $vmhost
        }

        $tag = ($_ | Get-TagAssignment).tag.name
        # Special rule for GPU VMs, to add GPUs to the VM
        if ($tag -eq "GPU_60_952_A100") {
            New-AdvancedSetting -Entity $_ -Name pciPassthru.use64bitMMIO -Value "TRUE" -Confirm:$false
            New-AdvancedSetting -Entity $_ -Name pciPassthru.64bitMMIOSizeGB -Value "1024" -Confirm:$false
            $gpus = $_ | Get-VMHost | Get-PassthroughDevice | Where-Object {$_.VendorName -like "NVIDIA*"}
            Add-PassthroughDevice $gpus -VM $_
        }
    }
    $vms | start-vm | wait-tools

    disconnect-viserver * -Confirm:$false
    # Send a slack message that this worked
    #$slackuri= ""
    #Send-SlackMessage -URI $slackuri -Text "$vmname has been H P C i f i e d"

    return $inputs
}
