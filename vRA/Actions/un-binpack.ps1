function handler($context, $inputs) {
    function Get-CouchVM($id){
        $month = Get-Date -Format yyyy-MM
        $dbvm = (Invoke-WebRequest -uri "$couchdbserver:6984/billing-$month/$id" -Headers $Headers ).Content
        $dbvm = $dbvm | ConvertFrom-Json 
        return $dbvm
    }

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
    
    # Find the host in reservations database
    $query=@"
    {
        "selector": {
            "vmname": {
                "`$eq": "$($inputs.resourceNames)"
             }
        },
        "fields": ["_id", "_rev", "sku","hostname","reservedstate","id","vmname"],
        "execution_stats": true
    }
"@
    $couchhost = (Invoke-WebRequest -uri "https://t01-couchdb01.las.r-hpc.com:6984/hpccapacity/_find" -Headers $Headers -AllowUnencryptedAuthentication -Method Post -Body $query -ContentType "application/json").Content
    $couchhost = $couchhost | ConvertFrom-Json | Select-Object -ExpandProperty docs
    write-host "Debug: Couch host is:"
    write-host $couchhost
    
    # Reset the host reservation
    if ($couchhost){
        $couchhost.vmname = ""
        $couchhost.reservedstate = "Free"
    
        $res = Invoke-WebRequest -uri "https://t01-couchdb01.las.r-hpc.com:6984/hpccapacity/$($couchhost.id)?rev=$($couchhost._rev)" -Method Put -Headers $Headers -AllowUnencryptedAuthentication -Body ($couchhost | ConvertTo-Json)
    }
    
    # Stop billing
    $vm = Get-CouchVM $inputs.resourceIds[0]
    $vm.endTime = "$(Get-Date -UFormat %s)"
    $vm | Add-Member -NotePropertyName "totalTime" -NotePropertyValue ($vm.endTime - $vm.startTime)
    Write-host "Debug: VM is $vm"
    $month = Get-Date -Format yyyy-MM
    $res = Invoke-WebRequest -uri "https://t01-couchdb01.las.r-hpc.com:6984/billing-$month/$($inputs.resourceIds[0])?rev=$($vm._rev)" -Method Put -Headers $Headers -Body ($vm | Select-Object -Property * -ExcludeProperty _rev | ConvertTo-Json)
    
    
    #Send event to log insight
    
    $json = @"
    {
    "events":[{
        "fields": [
            {"name": "vraEvent", "content": "VM Destroyed"},
            {"name": "resourceNames", "content": "$($inputs.resourceNames[0])"},
            {"name": "image", "content": "$($inputs.customProperties.image)"},
            {"name": "flavor", "content": "$($inputs.customProperties.flavor)"},
            {"name": "account", "content": "$($inputs.customProperties.accountNum)"},
            {"name": "test", "content": "False"}
        ],
        "text": "VM Destroyed $($inputs.resourceNames[0]) image $($inputs.customProperties.image) flavor $($inputs.customProperties.flavor) accountNum $($inputs.customProperties.accountNum)"
        }]
    }
"@

    $res = Invoke-WebRequest -URI https://t00-log.las.r-hpc.com:9543/api/v2/events/ingest/HPConDemand -Method Post -Body $json

    exit
}
