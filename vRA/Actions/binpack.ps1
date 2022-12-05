function handler($context, $inputs) {
 
  
    function Update-CouchHost($couchdbhost) {
        Invoke-WebRequest -uri "$couchdbserver:6984/hpccapacity/$($couchdbhost.id)?rev=$($couchdbhost._rev)" -Method Put -Headers $Headers -Body ($couchdbhost | ConvertTo-Json)
    }
    
    function Get-FreeCouchHost($sku){
        $query = @"
        {
            "selector": {
                "sku": {
                    "`$eq": "$sku"
                 },
                 "reservedstate": {
                    "`$eq": "Free"
                 }
            },
            "fields": ["_id", "_rev", "sku","hostname","reservedstate","id","vmname"],
            "execution_stats": true,
            "limit": 250
        }
"@
        write-host "Query $query"
        $dbhosts = (Invoke-WebRequest -uri "$couchdbserver:6984/hpccapacity/_find" -Headers $Headers -Method Post -Body $query -ContentType "application/json").Content
        $dbhosts = $dbhosts | ConvertFrom-Json | Select-Object -ExpandProperty docs
        return $dbhosts
    }
    
    # Copy entire $inputs object into new $outputs object
    $outputs = $inputs
    
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
    
    # Get the Flavor
    #$sku = $inputs.customProperties.flavor
    $flavor = $inputs.customProperties.flavor
    
    
    # Find Free hosts by SKU
    $couchosts = Get-FreeCouchHost $flavor
    write-host "sku $flavor"
    
    
    # Set aside all the vRA-suggested IDs
    $inputhosts = $inputs.hostSelectionIds
    
    # Filter to only hosts vRA suggested, sort by hostname
    $couchosts = $couchosts | Where-Object -Property id -in $inputhosts
    $couchosts = $couchosts | Sort-Object hostname
    write-host "Count $($couchosts.count)"
    
    # Check if there are enough hosts
    $requestsize = ($inputs.resourceNames).count
    if ($couchosts.count -lt $requestsize){
      Write-Host "Not enough capacity for the request"
      Write-Error 'Not enough capacity for the request' -ErrorAction Stop
    }
    
    # Remove extra hosts
    $outputs.hostSelectionIds = $outputs.hostSelectionIds[0..$($requestsize -1)]
    
    # Loop through available hosts, replace the output with the selected hosts
    $i=0
    while ($i -lt $requestsize){
      $outputs.hostSelectionIds[$i] = $couchosts[$i].id
      $i++
    }
    $couchosts = $couchosts[0..$($requestsize - 1)]
    
    # Mark hosts as reserved in CouchDB
    $i = 0
    foreach ($couchost in $couchosts){
        $couchost.reservedstate = "Reserved"
        $couchost.vmname = "$($inputs.resourceNames[$i])"
        Update-CouchHost $couchost
        $i++
    }
    
    #Send event to Log Insight
    $timestamp = Get-Date -uformat %s
    $i = 0
    While ($i -lt $couchosts.count){
        $json = @"
        {
        "events":[{
            "fields": [
                {"name": "vraEvent", "content": "VM Created"},
                {"name": "resourceNames", "content": "$($outputs.resourceNames[$i])"},
                {"name": "image", "content": "$($outputs.customProperties.image)"},
                {"name": "flavor", "content": "$($outputs.customProperties.flavor)"},
                {"name": "account", "content": "$($outputs.customProperties.accountNum)"},
                {"name": "hostSelectionId", "content": "$($outputs.hostSelectionIds[$i])"},
                {"name": "test", "content": "False"}
            ],
            "text": "VM Created $($outputs.resourceNames[$i]) image $($outputs.customProperties.image) flavor $($outputs.customProperties.flavor) accountNum $($outputs.customProperties.accountNum) hostSelectionId $($outputs.hostSelectionIds[$i])"
            }]
        }
"@
        $res = Invoke-WebRequest -URI https://t00-log.las.r-hpc.com:9543/api/v2/events/ingest/HPConDemand -Method Post -Body $json
        $i++
    }
    
    return $outputs
    #Write-host $outputs
}
