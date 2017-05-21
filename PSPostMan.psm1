$Defaults = @{
    NugetServerUrl = 'https://www.powershellgallery.com/api/v2/package/'
}

function New-Package
{
    [OutputType([void])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ 
			if (-not (Test-Path -Path $_ -PathType Container)) {
				throw "The folder '$_' does not exist."
			} else {
				$true
			}
		})]
        [string]$FolderPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Name = (Split-Path -Path $FolderPath -Leaf),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ 
			if (-not (Test-Path -Path $_ -PathType Container)) {
				throw "The folder '$_' does not exist."
			} else {
				$true
			}
		})]
        [string]$OutputFolderPath = $FolderPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [version]$Version,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Authors,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Owners,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LicenseUrl,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectUrl,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$IconUrl,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ReleaseNotes,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$Tags,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (-not (Compare-Object $_.Keys @('id','version'))) {
                throw 'One or more dependencies hashtables does not have the required keys: id and version.'
            } else {
                $true
            }
        })]
        [hashtable[]]$Dependencies,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [switch]$PassThru
    )
    begin
    {
        $ErrorActionPreference = 'Stop'
    }
    process
    {
        try
        {
            #region Build the nuget spec
            $specParamNames = @(
                'Version',
                'Authors',
                'Owners',
                'LicenseUrl',
                'ProjectUrl',
                'IconUrl',
                'ReleaseNotes',
                'Tags',
                'Dependencies'
            )

            $tempSpecFilePath = "$env:TEMP\$Name.nuspec"
            $specParams = @{
                Name = $Name
                FilePath = $tempSpecFilePath
                Force = $true
            }
            @($specParamNames).where({ $PSBoundParameters.ContainsKey($_) }).foreach({
                $specParams[$_] = (Get-Variable -Name $_).Value
            })

            $packSpec = New-PackageSpec @specParams
            #endregion

            ## Create the nuget package
            $result = nuget pack $packSpec.FullName -OutputDirectory $OutputFolderPath.TrimEnd('\') -BasePath $FolderPath.TrimEnd('\')
            if (($result -join ' ') -notmatch 'Successfully created package') {
                throw $result
            } elseif ($PassThru) {
                Get-Item -Path "$OutputFolderPath\$Name.$Version.nupkg"
            }
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($_)
        } 
        finally 
        {
            Remove-Item -Path $tempSpecFilePath -ErrorAction Ignore
        }
    }
}

function New-PackageSpec
{
    [OutputType([System.IO.FileInfo])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ 
			if ($_ -notmatch '\.nuspec$') {
				throw 'Invalid file path. Extension must be NUSPEC.'
			} else {
				$true
			}
		})]
        [string]$FilePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [switch]$Force,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [version]$Version = '1.0.0',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Authors = 'Adam Bertram',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Id = $Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Description = $Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Owners,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$LicenseUrl,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectUrl,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$IconUrl,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ReleaseNotes,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$Tags,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]$Dependencies
    )
    begin
    {
        $ErrorActionPreference = 'Stop'
    }
    process
    {
        try
        {
            if ((Test-Path -Path $FilePath -PathType Leaf) -and (-not $Force.IsPresent)) {
                throw "The file [$($FilePath)] already exists and -Force was not used to overwrite."
            }

            [xml]$xDoc = @"
<?xml version="1.0"?>
<package>
  <metadata>
    <id>$Id</id>
    <version>$($Version.ToString())</version>
    <authors>$Authors</authors>
    <description>$Description</description>
  </metadata>
</package>
"@

            $optionalNodes = @(
                "Owners"
                "LicenseUrl"
                "ProjectUrl"
                "IconUrl"
                "ReleaseNotes"
                "Tags"
                "Dependencies"
            )

            @($optionalNodes).where({ $PSBoundParameters.ContainsKey($_) }).foreach({
                if ($_ -eq 'Tags') {
                    $nodeName = $_ -join ' '
                } else {
                    $nodeName = $_
                }
                $nodeName = $nodeName.ToLower()
                $xNode = $xDoc.CreateElement($nodeName)
                if ($_ -eq 'Dependencies') {
                    @($Dependencies).foreach({
                        $xDep = $xNode.AppendChild($xDoc.CreateElement('dependency'))
                        $xDep.SetAttribute('id',$_.id)
                        $xDep.SetAttribute('version',$_.version)
                        $null = $xNode.AppendChild($xDep)
                    })
                } else {
                    $xNode.InnerText = (Get-Variable -Name $_).Value
                }
                $null = $xDoc.package.metadata.AppendChild($xNode)
            })

            $xDoc.Save($FilePath)
            Get-Item -Path $FilePath
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Publish-Package
{
    [OutputType([void])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ 
			if ($_ -notmatch '\.nupkg$') {
				throw 'Invalid file path. Extension must be NUPKG.'
			} else {
				$true
			}
		})]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FeedUrl,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ApiKey,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]$Timeout
    )
    begin
    {
        $ErrorActionPreference = 'Stop'
    }
    process
    {
        try
        {
            $nugetParams = [ordered]@{
                Timeout = "-timeout $Timeout"
                FeedUrl = "-source $FeedUrl"
                ApiKey = "-ApiKey $ApiKey"
            }
            $pushArgs = ''
            $nugetParams.GetEnumerator().where({$PSBoundParameters.ContainsKey($_.Key)}).foreach({
                $pushArgs += " $($_.Value)"
            })
            $pushArgs = $pushArgs.Trim()

            Write-Verbose -Message "Publishing package using Nuget args: [push `"$Path`" $pushArgs]"
            $result = Invoke-Expression "nuget push `"$Path`" $pushArgs"
            if (-not ($result -match 'package was pushed')) {
                throw $result
            }
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Remove-Package
{
    [OutputType([void])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory,ParameterSetName = 'NoPipeline')]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if (-not (Compare-Object $_.Keys @('Name','Version'))) {
                throw 'One or more hashtables in the Package parameter do not have Name/Version key/value pairs.'
            } else {
                $true
            }
        })]
        [hashtable]$PackageInfo,

        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName = 'Pipeline')]
        [ValidateNotNullOrEmpty()]
        [object]$Package,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Source')]
        [string]$FeedUrl = $Defaults.NugetServerUrl,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NuGetApiKey = 'secret'
    )
    begin
    {
        $ErrorActionPreference = 'Stop'
    }
    process
    {
        try
        {
            if ($PSBoundParameters.ContainsKey('Package'))
            {
                $pack = @{
                    Name = $Package.Name
                    Version = $Package.Version
                }
            } elseif ($PSBoundParameters.ContainsKey('PackageInfo')) {
                $pack = @{
                    Name = $PackageInfo.Name
                    Version = $PackageInfo.Version
                }
            }
            $nuGetCli = "nuget delete $($pack.Name) $($pack.Version) -NonInteractive -source $FeedUrl"
            if ($NuGetApiKey) {
                $nuGetCli += " -ApiKey $NuGetApiKey"
            }
            $result = Invoke-Expression $nuGetCli
            if (($result -join ' ') -notmatch 'was deleted successfully') {
                throw $result
            }
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Get-DependentModule
{
    [OutputType([System.Management.Automation.PSModuleInfo])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ModuleName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [switch]$Recurse
    )
    begin
    {
        $ErrorActionPreference = 'Stop'
    }
    process
    {
        try
        {
            if ($depModuleNames = Get-Module -Name $ModuleName -ListAvailable | Select-Object -ExpandProperty RequiredModules) {
                $depModules = Get-Module -Name $depModuleNames -ListAvailable
                if ($Recurse.IsPresent) {
                    Get-DependentModule -ModuleName $depModules.Name
                } else {
                    $depModules
                }
            }
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Publish-Module
{
    [OutputType([void])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$FeedUrl = $Defaults.NugetServerUrl,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NuGetApiKey = 'secret',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]$Timeout,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [switch]$PublishDependentModules,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$Tags
    )
    begin
    {
        $ErrorActionPreference = 'Stop'
    }
    process
    {
        try
        {
            $modulesToPublish = Get-Module -Name $Name -ListAvailable
            if (@($modulesToPublish).Count -ne @($Name).Count) {
                throw 'One or more modules could not be found.'
            }

            $publishPackParams = @{
                FeedUrl = $FeedUrl
            }
            if ($NuGetApiKey)
            {
                $publishPackParams.ApiKey = $NuGetApiKey
			}

            if (($depModules = Get-DependentModule -ModuleName $Name -Recurse) -and (-not $PublishDependentModules.IsPresent)) {
                throw "The module(s) [$($Name -join ',')] have dependent module(s) [$($depModules.Name -join ',')]. Use -PublishDependentModules to publish these as well."
            } else {
                @($depModules).foreach({
                    if (-not (Test-ModuleExists -Name $_.Name))
                    {
                        throw "The dependenent module [$($_.Name)] needs to be published but was not found."
                    }
                    else
                    {
                        Write-Verbose -Message "Creating package for module [$($_.Name)]..."
                        $pkg = New-Package -FolderPath $_.ModuleBase -PassThru -Version $_.Version
                        Publish-Package @publishPackParams -Path $pkg.FullName
                        Remove-Item -Path $pkg.FullName -ErrorAction Ignore
                    }
                })
            }

            @($modulesToPublish).foreach({
                $newPkgParams = @{
                    FolderPath = $_.ModuleBase
                    PassThru = $true
                    Version = $_.Version
                }
                if ($PSBoundParameters.ContainsKey('Tags'))
                {
                    $newPkgParams.Tags = $Tags
                }
                if ($depModules) {
                    $newPkgParams.Dependencies = @($depModules).foreach({
                        @{id=$_.Name;version=$_.Version}
                    })
                }
                $pkg = New-Package @newPkgParams
                Publish-Package @publishPackParams -Path $pkg.FullName
                Remove-Item -Path $pkg.FullName -ErrorAction Ignore    
            })
            
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Test-ModuleExists
{
    [OutputType([bool])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    begin
    {
        $ErrorActionPreference = 'Stop'
    }
    process
    {
        try
        {
            if (Get-Module -Name $Name -ListAvailable) {
                $true
            } else {
                $false
            }
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Find-Package
{
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$FeedUrl = $Defaults.NugetServerUrl

    )
    begin
    {
        $ErrorActionPreference = 'Stop'
    }
    process
    {
        try
        {
            if ($PSBoundParameters.ContainsKey('Name'))
            {
                $whereFilter = { $_ -match "^$($Name -join '|')" }
            } else {
                $whereFilter = { $_ }
            }

            $packageList = @(nuget list -Source $FeedUrl).where($whereFilter)
            if ($packageList -notmatch 'no packages found') {
                @($packageList).foreach({
                    $split = $_.Split(' ') 
                    $version = $split[-1]
                    if ($split.Count -eq 2) { 
                        $packageName = $split[0] 
                    } else { 
                        $packageName = $split[0..-2] -join ' '
                    } 
                    [pscustomobject]@{Name = $packageName; Version = $version}  
                })
            }
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Publish-DscResource
{
    ## TODO: Add pipeline support for Get-DscResource at some point
    [OutputType([void])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ 
            if (-not (Get-DscResource -Name $_ -ErrorAction Ignore)) {
                throw "The DSC resource [$($_)] was not found"
            } else {
                $true
            }

         })]
        [string[]]$Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$FeedUrl = $Defaults.NugetServerUrl,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$NuGetApiKey = 'secret',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [switch]$PublishDependentModules
    )
    begin
    {
        $ErrorActionPreference = 'Stop'
    }
    process
    {
        try
        {
            $publishPackParams = @{
                FeedUrl = $FeedUrl
            }
            if ($NuGetApiKey)
            {
                $publishPackParams.ApiKey = $NuGetApiKey
			}
			
			## TODO: Need to group these dependency checks together if multiple resources are passed so the same thing
			## isn't done for every resource. Could also makes these parallel
			
			## Ensure any and all dependent modules are available before proceeding
            @($Name).foreach({
                $resourceName = $_
                $resourceModule = Get-Module -Name (Get-DscResource -Name $resourceName).ModuleName -ListAvailable
                Write-Verbose -Message "The DSC resource [$($resourceName)] is in the module [$($resourceModule.Name)]"
                if ($dscModuleDeps = Get-DependentModule -ModuleName $resourceModule.Name) {
                    Write-Verbose -Message "Found [$($dscModuleDeps.Count)] dependent module(s)..."
						
					$depModulesInFeed = Find-Package -Name $dscModuleDeps.Name
                    @($dscModuleDeps).foreach({
						if ($_.Name -notin $depModulesInFeed.Name)
						{
							if (-not $PublishDependentModules.IsPresent)
							{
								throw "The dependent module [$($_.Name)] is not published to the feed specified. Downloading this module will fail if uploaded now. Use -PublishDependentModules."
							}
							else
							{
								if (-not (Test-ModuleExists -Name $_.Name))
								{
									throw "The dependenent module [$($_.Name)] needs to be published but was not found."
								}
								else
								{
                                    Publish-Module -FeedUrl $FeedUrl -Name $_.Name -
									Write-Verbose -Message "Creating package for module [$($_.Name)]..."
									$pkg = New-Package -FolderPath $_.ModuleBase -PassThru -Version $_.Version
									Publish-Package @publishPackParams -Path $pkg.FullName
									Remove-Item -Path $pkg.FullName -ErrorAction Ignore
								}
							}
						}
								
					})
                }
                $newPkgParams = @{
                    FolderPath = $resourceModule.ModuleBase
                    PassThru = $true
                    Version = $resourceModule.Version
                    Tags = "PsDscResource_$resourceName" ## Required for Find-DscResource to find the module
                }
                if ($dscModuleDeps) {
                    $newPkgParams.Dependencies = @($dscModuleDeps).foreach({
                        @{id=$_.Name;version=$_.Version}
                    })
                }
                $pkg = New-Package @newPkgParams
                Publish-Package @publishPackParams -Path $pkg.FullName
                Remove-Item -Path $pkg.FullName -ErrorAction Ignore
            })
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}