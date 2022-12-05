function handler($context, $inputs) {
    # Copy entire $inputs object into new $outputs object
    $outputs = $inputs

    
    #VC credentials
    $vcuser = $context.getSecret($inputs.uservra)
    $vcpass = $context.getSecret($inputs.passwordvra)
    $vc = $context.getSecret($inputs.vcenter)
    Connect-VIServer $vc -user $vcuser -password $vcpass -protocol https -Force
    
    #Get type/flavor of server from inputs
    $flavor = ($inputs.customProperties.flavor).Split("_")[0]
    $type = switch ($flavor) {
        GP  {"login"}
        HPC {"compute"}
        GPU {"gpu"}
    }
    
    # Set type to lowercase
    $type = $type.ToLower()
    
    # Get list of names
    $namelist = $inputs.resourceNames
    $name = $inputs.resourceNames[0]
    Write-host "Name is $name"
    # Get account number 
    $acct = $name.Split("-")[0]
    # Set account to uppercase
    $acct = $acct.ToUpper()
    Write-host "Acct is $acct"
    # Get accounts existing VMs
    $vms = Get-VM -name "$acct*"
    Write-Host "VM list is $vms"
    $index = 0
    $counter = 1
    foreach ($resname in $namelist) {
        $old_name = $inputs.resourceNames[$index]
        $suffix = "{0:000}" -f $counter
        # Concatenate new hostname based on custom properties and formatted incremental number
        $new_name = "$acct-$type$suffix"
        # Check list of existing VMs.  If the new name already exists, count up until it's the next number
        while ($new_name -in $vms.name) {
            $counter++
            $suffix = "{0:000}" -f $counter
            $new_name = "$acct-$type$suffix"
        }
        # If it's a login node, there can be only 1
        if ($type -eq "login") {
            $new_name = "$acct-login001"
        }
        # Overwrite .resourceNames[] property with new hostname
        $outputs.resourceNames[$index] = $new_name
        $index ++
        $counter++
        # Create output entry visible in Action Runs logs
        Write-Output ("Setting machine name from " + $old_name + " to " + $new_name)

    }
   
    # Return updated outputs object containing new hostname used for remainder of deployment process
    disconnect-viserver -confirm:$false
    return $outputs
}
