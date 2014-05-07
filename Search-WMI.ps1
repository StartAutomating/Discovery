function Search-Wmi
{
	<#
	.Synopsis
		Searches the WMI repository
	.Description
		Searches the help metadata that is built into the WMI repository
		to find WMI classes to fit a particular need.  The search can
		look for:
			- Information by class name
			- Keywords in the description text
			- Keywords in property names or descriptions
			- Keywords in method names or descriptions			
	.Example
        # Get all class information from root\cimv2 namespace
        Search-WMI 
    .Example
        # 
        Search-Wmi -ForName *registry* -Namespace root\default
    .Example
        # Save Everything in Root Default
        Search-Wmi -Namespace root\default | Export-Clixml .\root.default.clixml
	#>
	param(
		[Parameter(ValueFromPipelineByPropertyName=$true)]
		[String]$ForName = "*",
		[Parameter(ValueFromPipelineByPropertyName=$true)]
		[String]$ForTextInDescription,
		[Parameter(ValueFromPipelineByPropertyName=$true)]
		[string]$ForAPropertyLike,
		[switch]$OnlyIfThePropertyCanWrite,
		[Parameter(ValueFromPipelineByPropertyName=$true)]
		[string]$ForAMethodLike,
		[Parameter(ValueFromPipelineByPropertyName=$true)]
		[string]$Namespace = "root\cimv2",
		[switch]$OnlyIfItCanBeCreated,
		[switch]$OnlyIfItCanBeDeleted,
		[switch]$OnlyIfItCanBeUpdated,		
		[string]$ComputerName,
		[Management.Automation.PSCredential]$Credential,
		[Switch]$Recurse,
		[Switch]$OnlySearchForAnEvent
	)
	
    
    process {
    	Get-WmiObject $ForName -Namespace $namespace -Recurse:$Recurse -Amended -List | 
    		Select-Object @{
    				Name='Class'
    				Expression={
    					Write-Progress "Getting WMI Data" " $($_.Name)"
    					$_.Name
    				
    				}				
    			}, @{
    				Name='Namespace'
    				Expression={
    					$_.__Namespace 
    				}
    			}, @{
    				Name='Description'
    				Expression={
                        
    					$_.Qualifiers.Item("Description").Value
    				}
    			},@{
    				Name='CanCreate'
    				Expression={
    					try {
    						[bool]($_.Qualifiers.Item('SupportsCreate'))
    					} catch {
    						$false 
    					}					
    				}
    			}, @{
    				Name='CanUpdate'
    				Expression={
    					try {
    						[bool]($_.Qualifiers.Item('SupportsUpdate'))
    					} catch {
    						$false
    					}}				
    			}, @{
    				Name='CanDelete'
    				Expression={
    					try {
    						[bool]$_.Qualifiers.Item('SupportsDelete')				
    					} catch {
    						$false
    					}
    					
    				}
    			}, @{
    				Name='Properties'
    				Expression={
    					$_.Properties | 
    						Select-Object @{
    							Label='PropertyName'
    							Expression={$_.Name}
    						}, @{
    							Label='Description'
    							Expression={$_.Qualifiers.Item("Description").Value}
    						}, @{
    							Label='CanRead'
    							Expression={$_.Qualifiers.Item("Read").Value}
    						}, @{
    							Label='CanWrite'
    							Expression={
    								try {
    									$_.Qualifiers.Item("Write").Value
    								} catch {
    									$false
    								}}
    						}
    				}
    			}, @{
    				Name='Methods'
    				Expression={
    					$_.Methods | 
    						Select-Object @{
    							Label='MethodName'
    							Expression={$_.Name}
    						}, @{
    							Label='Description'
    							Expression={$_.Qualifiers.Item("Description").Value}
    						}			
    				}
    			}, @{
    				Name='IsEvent'
    				Expression = { $_.Derivation -contains '__Event' } 
    			}, @{
                    Name='ValueMaps'
                    Expression = {
                        $_.psbase.properties | 
                            Where-Object {
                                $_.Qualifiers['ValueMap'] -and $_.Qualifiers['Values']
                            } | 
                            ForEach-Object -Begin {
                                $ht = @{}
                            } -End {
                                $ht
                            } -Process {
                                $name = $_.Name
                                $valueMap = $_.Qualifiers['ValueMap'].Value -split ([Environment]::NewLine)
                                $values= $_.Qualifiers['Values'].Value -split ([Environment]::NewLine)
                                
                                $lookupScript = ""
                                for ($i= 0;$i-lt $values.Count;$i++) {
                                    if (-not ($ValueMap[$i] -as [int])) { continue }
                                    $lookupScript += "if (`$this.psbase.properties['$name'].value -eq $($valueMap[$i])) { return '$($values[$i])'}
" 

                               }
                                
                                $lookupScript += "return 'Unknown'"
                            
                                #$lookupScript       
                                $ht.$name = [ScriptBlock]::Create($lookupScript)            
                            }                        
                    }
                }|
    			Where-Object {
    				if ($OnlyIfItCanBeCreated) {
    					$stillOk = $_.CanCreate
    					if (-not $stillOk) { return } 
    				}
    				if ($OnlyIfItCanBeDeleted) {
    					$stillOk = $_.CanDelete
    					if (-not $stillOk) { return } 
    				}
    				if ($OnlyIfItCanBeUpdated) {
    					$stillOk = $_.CanUpdate
    					if (-not $stillOk) { return }
    				}
    				if ($ForAPropertyLike) {
    					$stillOk = $_.Properties | 
    							Where-Object { 
    								($_.PropertyName -like $ForAPropertyLike -or
    								$_.Description -like $ForAPropertyLike) -and 
    								(((-not $OnlyIfThePropertyCanWrite) -or 
    								($OnlyIfThePropertyCanWrite -and $_.CanWrite)))
    							}
    					if (-not $stillOk ) { return }
    				}
    				
    				if ($ForAMethodLike) {
    					$stillOk = $_.Methods | 
    						Where-Object  {
    							$_.MethodName -like $ForAMethodLike -or
    							$_.Description -like $ForAMethodLike
    						}
    					if (-not $stillOk) { return }
    				}
    				
    				if ($OnlySearchForAnEvent) {
    					$stillOk = $_.IsEvent
    					if (-not $stillOk) { return }
    				}
    				
    				if ($ForTextInDescription) {
    					$stillOk = $_.Description -like "*$ForTextInDescription*"
    					if (-not $stillOk) { return } 
    				}
         
                    
    								
    				return $true				
    			
    			} | ForEach-Object {
    				$_.psobject.typenames.clear()
                    $_.psobject.typenames.add('WmiInfo')
    				$_
    			}
    	
    	Write-Progress "Getting WMI Data" "Complete" -Completed
    }	
}