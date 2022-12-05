## v 1.0 April 27 2017
## https://github.com/vdudejon/Powershell/blob/master/Add-OMCustomProperty.psm1

function Add-OMCustomProperty {
	param($objname, $propname, $propvalue)
	
	# Time stamp
	[DateTime]$NowDate = (Get-date)
	[int64]$NowDateEpoc = Get-Date -Date $NowDate.ToUniversalTime() -UFormat %s
	$NowDateEpoc = $NowDateEpoc*1000

	# New objects for API call
	$contentprops = New-Object VMware.VimAutomation.vROps.Views.PropertyContents
	$contentprop = New-Object VMware.VimAutomation.vROps.Views.PropertyContent
	
	$contentprop.StatKey = $propname
	$contentprop.Values = $propvalue
	$contentprop.Timestamps = $NowDateEpoc

	# Add custom property objects to contentproperties object
	$contentprops.Propertycontent = @($contentprop)
	
	$obj = Get-OMResource -Name $objname
	
	# Add properties to resource
	$obj.ExtensionData.AddProperties($contentprops)
}
