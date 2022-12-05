$vmhosts = Get-cluster -name "" | Get-VMHost -State "Maintenance" | Sort-Object Name
foreach ($vmhost in $vmhosts) {
    # Add Tags
    $vmhost | New-TagAssignment -Tag (Get-Tag -Name "Free") -Confirm:$false
    $vmhost | New-TagAssignment -Tag (Get-Tag -Name "HPC_44_140_CascadeLake") -Confirm:$false
    #$vmhost | New-TagAssignment -Tag (Get-Tag -Name "HPC_52_448_IceLake") -Confirm:$false

    #Configure NTP server
    $ntp = $vmhost | Get-VMHostNtpServer
    #if ($ntp) {continue}
    if (!$ntp){
        Add-VmHostNtpServer -VMHost $vmhost -NtpServer 10.91.0.5
        Add-VmHostNtpServer -VMHost $vmhost -NtpServer 10.91.0.4
        #Allow NTP queries outbound through the firewall
        Get-VMHostFirewallException -VMHost $vmhost | where {$_.Name -eq "NTP client"} | Set-VMHostFirewallException -Enabled:$true
        #Start NTP client service and set to automatic
        Get-VmHostService -VMHost $vmhost | Where-Object {$_.key -eq "ntpd"} | Start-VMHostService
        Get-VmHostService -VMHost $vmhost | Where-Object {$_.key -eq "ntpd"} | Set-VMHostService -policy "automatic"
    }

    # Migrate to dVSwitches
    $dvs = $vmhost | Get-VDSwitch
    if ("T01-HPC" -notin $dvs.name){
        $hpcswitch = Get-VDSwitch -name "*HPC*" 
        $hpcswitch | Add-VDSwitchVMHost -vmhost $vmhost
        # Cascade Lake
        $hpcnic = $vmhost | Get-VMHostNetworkAdapter -name "vmnic2" -Physical
        # Ice Lake
        #$hpcnic = $vmhost | Get-VMHostNetworkAdapter -name "vmnic4" -Physical
        $hpcswitch | Add-VDSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $hpcnic -Confirm:$false    
    }
    if ("T01-External" -notin $dvs.name ){
        $switch = Get-VDSwitch -name "*External*"
        $switch | Add-VDSwitchVMHost -vmhost $vmhost
        # Cascade Lake
        $nic = $vmhost | Get-VMHostNetworkAdapter -name "vmnic0" -Physical
        # Ice Lake
        #$nic = $vmhost | Get-VMHostNetworkAdapter -name "vmnic2" -Physical
        $virtualNic = Get-VMHostNetworkAdapter -VMHost $vmhost -Name "vmk0"
        $pg = Get-VDPortgroup -name "*Mgmt*"
        $switch | Add-VDSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $nic -VMHostVirtualNic $virtualNic -VirtualNicPortgroup $pg -Confirm:$false 
        # Cascade Lake
        $nic = $vmhost | Get-VMHostNetworkAdapter -name "vmnic1" -Physical
        # Ice Lake
        #$nic = $vmhost | Get-VMHostNetworkAdapter -name "vmnic3" -Physical
        $switch | Add-VDSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $nic -Confirm:$false
    }

    # Add vmotion and vsan ports
    $vmks = $vmhost | Get-VMHostNetworkAdapter -VMKernel
    if ("vmk2" -notin $vmks.name){
        $pg = Get-VDPortgroup -name "*vmot*"
        New-VMHostNetworkAdapter -VMHost $vmhost -VirtualSwitch $switch[0] -PortGroup $pg -VMotionEnabled:$true -mtu 9000
    }
    if ("vmk3" -notin $vmks.name ){
        $pg = Get-VDPortgroup -name "*-vsan*"
        New-VMHostNetworkAdapter -VMHost $vmhost -VirtualSwitch $switch -PortGroup $pg -VsanTrafficEnabled:$true -mtu 9000
    }

    # Remove default vswitch0
    $vswitch = $vmhost | Get-VirtualSwitch -name "vSwitch0"
    if ($vswitch){  
        $vswitch | Remove-VirtualSwitch -Confirm:$false -ErrorAction SilentlyContinue
    }  
    # Rename Local datastores
    $localds = $vmhost | Get-Datastore -name "datastore1*" -ErrorAction SilentlyContinue
    if ($localds){
        $localds | Set-Datastore -Name "$($vmhost.name.Split(".")[0])-local"
    } 
}
