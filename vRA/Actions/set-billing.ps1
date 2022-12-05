function handler($context, $inputs) {
    $user = $context.getSecret($inputs.uservra)
    $password = $context.getSecret($inputs.passwordvra)
    Connect-VIServer t01-vcenter.las.r-hpc.com -User $user -Password $password -Force
    
    # CouchDB Creds
    $couchdbserver = ""
    $user = $context.getSecret($inputs.couchuser)
    $pass = $context.getSecret($inputs.couchpass)
    $pair = "$($user):$($pass)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $basicAuthValue = "Basic $encodedCreds"
    $Headers = @{
        Authorization = $basicAuthValue
    }
    
    $json = @"
    {
        "_id": "$($inputs.resourceIds[0])",
        "accountNum": "$($inputs.resourceNames[0].Split("-")[0])",
        "vmName": "$($inputs.resourceNames[0])",
        "resourceId": "$($inputs.resourceIds[0])",
        "startTime": "$(Get-Date -UFormat %s)",
        "endTime": "",
        "sku": "$($inputs.customProperties.flavor)",
        "vsan": $(((Get-VM $inputs.resourceNames[0] | Get-HardDisk).CapacityGB | Measure-Object -Sum).sum)
    }
"@
    
    $month = Get-Date -Format yyyy-MM
    $res = Invoke-WebRequest -uri "https://$couchdbserver:6984/billing-$month/$($inputs.resourceIds[0])" -Method Put -Headers $Headers -Body $json
    write-host "Debug json:" $json
    write-host $res
    exit
}
