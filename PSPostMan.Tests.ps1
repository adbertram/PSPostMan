#region import modules
$ThisModule = "$($MyInvocation.MyCommand.Path -replace '\.Tests\.ps1$', '').psd1"
$ThisModuleName = (($ThisModule | Split-Path -Leaf) -replace '\.psd1')
Get-Module -Name $ThisModuleName -All | Remove-Module -Force

Import-Module -Name $ThisModule -Force -ErrorAction Stop
#endregion

describe 'Module-level tests' {
	
	it 'should validate the module manifest' {
	
		{ Test-ModuleManifest -Path $ThisModule -ErrorAction Stop } | should not throw
	}

	it 'should pass all error-level script analyzer rules' {
		Invoke-ScriptAnalyzer -Path $PSScriptRoot -Severity Error
	}

	it 'should have nuget.exe included' {
		Test-Path "$PSScriptRoot\nuget.exe" | should be $true
	}

}

InModuleScope $ThisModuleName {

	$Defaults = @{
		NugetServerUrl = 'https://www.powershellgallery.com/api/v2/package/'
		LocalNuGetExePath = 'C:\folder\nuget.exe'
		NuGetExeUrl = 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe'
	}

	describe 'New-PmModulePackage' {
	
		$commandName = 'New-PmModulePackage'
		$command = Get-Command -Name $commandName
	
		#region Mocks
			mock 'New-PmPackage' {} -ParameterFilter { -not $PassThru }

			mock 'New-PmPackage' { 
				New-MockObject -Type 'System.IO.FileInfo'
			} -ParameterFilter { $PassThru }
		#endregion
		
		$testModulePath = 'TestDrive:\module'
		$null = mkdir $testModulePath
		Add-Content -Path "$testModulePath\module.psd1" -Value "@{ 
			ModuleVersion = '1.0'
			Description = 'deschere'
			Author = 'Adam Bertram'
			PrivateData = @{
				PSData = @{
					ProjectUri = 'projecturihere'
					Tags = @('PSModule')
				}
			}
		}"
		Add-Content -Path "$testModulePath\module.psm1" -Value ''
		
		$parameterSets = @(
			@{
				Path = $testModulePath
				TestName = 'Mandatory parameters'
			}
			@{
				Path = $testModulePath
				PassThru = $true
				TestName = 'Mandatory parameters'
			}
		)
	
		$testCases = @{
			All = $parameterSets
			NoPassThru = $parameterSets.where({-not $_.ContainsKey('PassThru')})
			PassThru = $parameterSets.where({$_.ContainsKey('PassThru')})
		}

		context 'when PassThru is used' {
		
			it 'should should return the same object in OutputType: <TestName>' -TestCases $testCases.PassThru {
				param($Path,$PassThru)
			
				$result = & $commandName @PSBoundParameters
			}
		
		}

		context 'when PassThru is not used' {
		
			it 'returns nothing: <TestName>' -TestCases $testCases.NoPassThru {
				param($Path,$PassThru)

				& $commandName @PSBoundParameters | should benullOrEmpty
	
			}	
		
		}

		it 'should create the package with the expected parameters: <TestName>' -TestCases $testCases.All {
			param($Path,$PassThru)
		
			$result = & $commandName @PSBoundParameters

			$assMParams = @{
				CommandName = 'New-PmPackage'
				Times = 1
				Exactly = $true
				Scope = 'It'
				ParameterFilter = { 
					$PSBoundParameters.Name -eq 'module' -and
					$PSBoundParameters.Path -eq $Path -and
					$PSBoundParameters.OutputFolderPath -eq $Path
					$PSBoundParameters.Version -eq '1.0' -and
					$PSBoundParameters.Desription -eq 'deschere'
					$PSBoundParameters.Authors -eq 'Adam Bertram' -and
					(diff $PSBoundParameters.Tags @('PSModule')) -eq $null -and
					$PSBoundParameters.ProjectUrl -eq 'projecturihere' 
				
				}
			}
			Assert-MockCalled @assMParams
		}
	
		# context 'Help' {
			
		# 	$nativeParamNames = @(
		# 		'Verbose'
		# 		'Debug'
		# 		'ErrorAction'
		# 		'WarningAction'
		# 		'InformationAction'
		# 		'ErrorVariable'
		# 		'WarningVariable'
		# 		'InformationVariable'
		# 		'OutVariable'
		# 		'OutBuffer'
		# 		'PipelineVariable'
		# 		'Confirm'
		# 		'WhatIf'
		# 	)
			
		# 	$command = Get-Command -Name $commandName
		# 	$commandParamNames = [array]($command.Parameters.Keys | where {$_ -notin $nativeParamNames})
		# 	$help = Get-Help -Name $commandName
		# 	$helpParamNames = $help.parameters.parameter.name
			
		# 	it 'has a SYNOPSIS defined' {
		# 		$help.synopsis | should not match $commandName
		# 	}
			
		# 	it 'has at least one example' {
		# 		$help.examples | should not benullorempty
		# 	}
			
		# 	it 'all help parameters have a description' {
		# 		$help.Parameters | where { ('Description' -in $_.Parameter.PSObject.Properties.Name) -and (-not $_.Parameter.Description) } | should be $null
		# 	}
			
		# 	it 'there are no help parameters that refer to non-existent command paramaters' {
		# 		if ($commandParamNames) {
		# 		@(Compare-Object -ReferenceObject $helpParamNames -DifferenceObject $commandParamNames).where({
		# 			$_.SideIndicator -eq '<='
		# 		}) | should benullorempty
		# 		}
		# 	}
			
		# 	it 'all command parameters have a help parameter defined' {
		# 		if ($commandParamNames) {
		# 		@(Compare-Object -ReferenceObject $helpParamNames -DifferenceObject $commandParamNames).where({
		# 			$_.SideIndicator -eq '=>'
		# 		}) | should benullorempty
		# 		}
		# 	}
		# }
	}

	describe 'Publish-PmPackage' {
	
		$commandName = 'Publish-PmPackage'
		$command = Get-Command -Name $commandName
	
		#region Mocks
			mock 'Invoke-Expression' {
				'package was pushed'
			}
		#endregion
		
		$parameterSets = @(
			@{
				Path = 'C:\Path\package.nupkg'
				FeedUrl = 'feedurlhere'
				ApiKey = 'apikeyhere'
				TestName = 'Mandatory parameters'
			}
			@{
				Path = 'C:\Path\package.nupkg'
				FeedUrl = 'feedurlhere'
				ApiKey = 'apikeyhere'
				Timeout = 10
				TestName = 'Mandatory parameters'
			}
		)
	
		$testCases = @{
			All = $parameterSets
			WithTimeout = $parameterSets.where({$_.ContainsKey('Timeout')})
			NoTimeout = $parameterSets.where({-not $_.ContainsKey('Timeout')})
		}

		context 'when no timeout specified' {
		
			it 'should invoke nuget.exe with the expected arguments: <TestName>' -TestCases $testCases.NoTimeout {
				param($Path,$FeedUrl,$ApiKey,$Timeout)
			
				$result = & $commandName @PSBoundParameters

				$assMParams = @{
					CommandName = 'Invoke-Expression'
					Times = 1
					Exactly = $true
					Scope = 'It'
					ParameterFilter = { 
						$matchString = [regex]::Escape(("& '{3}' push `"{0}`" -source {1} -ApiKey {2}" -f $Path,$FeedUrl,$ApiKey,$Defaults.LocalNuGetExePath))
						$PSBoundParameters.Command -match $matchString
					}
				}
				Assert-MockCalled @assMParams
			}
		
		}

		context 'when a timeout is specified' {
		
			it 'should invoke nuget.exe with the expected arguments: <TestName>' -TestCases $testCases.WithTimeout {
				param($Path,$FeedUrl,$ApiKey,$Timeout)
			
				$result = & $commandName @PSBoundParameters

				$assMParams = @{
					CommandName = 'Invoke-Expression'
					Times = 1
					Exactly = $true
					Scope = 'It'
					ParameterFilter = { 
						$matchString = [regex]::Escape(("& '{4}' push `"{0}`" -timeout {1} -source {2} -ApiKey {3}" -f $Path,$Timeout,$FeedUrl,$ApiKey,$Defaults.LocalNuGetExePath))
						$PSBoundParameters.Command -match $matchString
					}
				}
				Assert-MockCalled @assMParams
			}
		
		}

		context 'when nuget.exe does not return a success indicator' {
			
			mock 'Invoke-Expression' {
				'error!'
			}

			it 'should throw an exception with nuget.exe output: <TestName>' -TestCases $testCases.All {
				param($Path,$FeedUrl,$ApiKey,$Timeout)
			
				$params = @{} + $PSBoundParameters
				{ & $commandName @params } | should throw 'error!'
			}
			
		
		}
		
		it 'returns nothing: <TestName>' -TestCases $testCases.All {
			param($Path,$FeedUrl,$ApiKey,$Timeout)
	
			& $commandName @PSBoundParameters | should benullorempty
	
		}
	
		# context 'Help' {
			
		# 	$nativeParamNames = @(
		# 		'Verbose'
		# 		'Debug'
		# 		'ErrorAction'
		# 		'WarningAction'
		# 		'InformationAction'
		# 		'ErrorVariable'
		# 		'WarningVariable'
		# 		'InformationVariable'
		# 		'OutVariable'
		# 		'OutBuffer'
		# 		'PipelineVariable'
		# 		'Confirm'
		# 		'WhatIf'
		# 	)
			
		# 	$command = Get-Command -Name $commandName
		# 	$commandParamNames = [array]($command.Parameters.Keys | where {$_ -notin $nativeParamNames})
		# 	$help = Get-Help -Name $commandName
		# 	$helpParamNames = $help.parameters.parameter.name
			
		# 	it 'has a SYNOPSIS defined' {
		# 		$help.synopsis | should not match $commandName
		# 	}
			
		# 	it 'has at least one example' {
		# 		$help.examples | should not benullorempty
		# 	}
			
		# 	it 'all help parameters have a description' {
		# 		$help.Parameters | where { ('Description' -in $_.Parameter.PSObject.Properties.Name) -and (-not $_.Parameter.Description) } | should be $null
		# 	}
			
		# 	it 'there are no help parameters that refer to non-existent command paramaters' {
		# 		if ($commandParamNames) {
		# 		@(Compare-Object -ReferenceObject $helpParamNames -DifferenceObject $commandParamNames).where({
		# 			$_.SideIndicator -eq '<='
		# 		}) | should benullorempty
		# 		}
		# 	}
			
		# 	it 'all command parameters have a help parameter defined' {
		# 		if ($commandParamNames) {
		# 		@(Compare-Object -ReferenceObject $helpParamNames -DifferenceObject $commandParamNames).where({
		# 			$_.SideIndicator -eq '=>'
		# 		}) | should benullorempty
		# 		}
		# 	}
		# }
	}

	describe 'Publish-PmModule' {
	
		$commandName = 'Publish-PmModule'
		$command = Get-Command -Name $commandName

		$script:availModules = @(
			[pscustomobject]@{
					ModuleBase = 'C:\mymodule1'	
				}
			[pscustomobject]@{
				ModuleBase = 'C:\mymodule2'	
			}
		)
	
		#region Mocks
			mock 'Get-Module' {
				$script:availModules
			} -ParameterFilter { @($Name).Count -gt 1}

			mock 'Get-Module' {
				$script:availModules | where {$_.ModuleBase -eq 'C:\mymodule1' }
			} -ParameterFilter { @($Name).Count -eq 1}

			mock 'New-PmModulePackage' {
				$obj = New-MockObject -Type 'System.IO.FileInfo'
				$obj | Add-Member -MemberType NoteProperty -Name 'FullName' -Force -Value 'C:\mymodule.nupkg' -PassThru
			} -ParameterFilter { $PassThru }

			mock 'New-PmModulePackage'

			mock 'Publish-PmPackage'

			mock 'Get-DependentModule'
		#endregion
		
		$parameterSets = @(
			@{
				Name = 'mymodule'
				NuGetApiKey = 'nugetapikeyhere'
				TestName = 'Parameter Set: ByName / Mandatory Parameters'
			}
			@{
				Path = 'C:\mymodule'
				NuGetApiKey = 'nugetapikeyhere'
				TestName = 'Parameter Set: ByPath / Mandatory Parameters'
			}
		)
	
		$testCases = @{
			All = $parameterSets
			ByName = $parameterSets.where({$_.ContainsKey('Name')})
			ByPath = $parameterSets.where({$_.ContainsKey('Path')})
		}

		context 'when not all modules provided can be found' {
			
			mock 'Get-Module' -ParameterFilter { $Name }

			it 'should throw an exception: <TestName>' -TestCases $testCases.All {
				param($Name,$Path,$NuGetApiKey,$FeedUrl,$Timeout,$PublishDependencies)
			
				$params = @{} + $PSBoundParameters
				{ & $commandName @params } | should throw 'One or more modules could not be found'
			}
			
		
		}

		context 'when called with a module name' {
		
			it 'should find the module with the expected name: <TestName>' -TestCases $testCases.ByName {
				param($Name,$Path,$NuGetApiKey,$FeedUrl,$Timeout,$PublishDependencies)
			
				$result = & $commandName @PSBoundParameters

				$assMParams = @{
					CommandName = 'Get-Module'
					Times = 1
					Exactly = $true
					Scope = 'It'
					ParameterFilter = { $PSBoundParameters.Name -eq 'mymodule' }
				}
				Assert-MockCalled @assMParams
			}	
		
		}

		context 'when called with a folder path' {
		
			it 'should find the module with the expected name: <TestName>' -TestCases $testCases.ByPath {
				param($Name,$Path,$NuGetApiKey,$FeedUrl,$Timeout,$PublishDependencies)
			
				$result = & $commandName @PSBoundParameters

				$assMParams = @{
					CommandName = 'Get-Module'
					Times = 1
					Exactly = $true
					Scope = 'It'
					ParameterFilter = { $PSBoundParameters.Name -eq 'C:\mymodule' }
				}
				Assert-MockCalled @assMParams
			}	
		
		}

		context 'when the module has dependent modules' {
		
			mock 'Get-DependentModule' {
				[pscustomobject]@{
					Name = 'depmodule1'
					Version = 'depmodule1version'
					ModuleBase = 'depmodule1modulebase'
				}
			}
		
		}

		it 'should return nothing: <TestName>' -TestCases $testCases.All {
			param($Name,$Path,$NuGetApiKey,$FeedUrl,$Timeout,$PublishDependencies)
	
			& $commandName @PSBoundParameters | should benullOrEmpty

		}

		it 'should use the expected module folder to create package: <TestName>' -TestCases $testCases.All {
			param($Name,$Path,$NuGetApiKey,$FeedUrl,$Timeout,$PublishDependencies)
		
			$result = & $commandName @PSBoundParameters

			$assMParams = @{
				CommandName = 'New-PmModulePackage'
				Times = @($Name).Count
				Exactly = $true
				Scope = 'It'
				ParameterFilter = { $PSBoundParameters.Path -in $script:availModules.ModuleBase }
			}
			Assert-MockCalled @assMParams
		}

		it 'should use the created package to publish: <TestName>' -TestCases $testCases.All {
			param($Name,$Path,$NuGetApiKey,$FeedUrl,$Timeout,$PublishDependencies)
		
			$result = & $commandName @PSBoundParameters

			$assMParams = @{
				CommandName = 'Publish-PmPackage'
				Times = @($Name).Count
				Exactly = $true
				Scope = 'It'
				ParameterFilter = { $PSBoundParameters.Path -eq 'C:\mymodule.nupkg' }
			}
			Assert-MockCalled @assMParams
		}

		it 'should use the expected URL for publishing: <TestName>' -TestCases $testCases.All {
			param($Name,$Path,$NuGetApiKey,$FeedUrl,$Timeout,$PublishDependencies)
		
			$result = & $commandName @PSBoundParameters

			$assMParams = @{
				CommandName = 'Publish-PmPackage'
				Times = @($Name).Count
				Exactly = $true
				Scope = 'It'
				ParameterFilter = { $PSBoundParameters.FeedUrl -eq $FeedUrl }
			}
			Assert-MockCalled @assMParams
		}

		it 'should use the expected API key for publishing: <TestName>' -TestCases $testCases.All {
			param($Name,$Path,$NuGetApiKey,$FeedUrl,$Timeout,$PublishDependencies)
		
			$result = & $commandName @PSBoundParameters

			$assMParams = @{
				CommandName = 'Publish-PmPackage'
				Times = @($Name).Count
				Exactly = $true
				Scope = 'It'
				ParameterFilter = { $PSBoundParameters.ApiKey -eq $NuGetApiKey }
			}
			Assert-MockCalled @assMParams
		}
	
		# context 'Help' {
			
		# 	$nativeParamNames = @(
		# 		'Verbose'
		# 		'Debug'
		# 		'ErrorAction'
		# 		'WarningAction'
		# 		'InformationAction'
		# 		'ErrorVariable'
		# 		'WarningVariable'
		# 		'InformationVariable'
		# 		'OutVariable'
		# 		'OutBuffer'
		# 		'PipelineVariable'
		# 		'Confirm'
		# 		'WhatIf'
		# 	)
			
		# 	$command = Get-Command -Name $commandName
		# 	$commandParamNames = [array]($command.Parameters.Keys | where {$_ -notin $nativeParamNames})
		# 	$help = Get-Help -Name $commandName
		# 	$helpParamNames = $help.parameters.parameter.name
			
		# 	it 'has a SYNOPSIS defined' {
		# 		$help.synopsis | should not match $commandName
		# 	}
			
		# 	it 'has at least one example' {
		# 		$help.examples | should not benullorempty
		# 	}
			
		# 	it 'all help parameters have a description' {
		# 		$help.Parameters | where { ('Description' -in $_.Parameter.PSObject.Properties.Name) -and (-not $_.Parameter.Description) } | should be $null
		# 	}
			
		# 	it 'there are no help parameters that refer to non-existent command paramaters' {
		# 		if ($commandParamNames) {
		# 		@(Compare-Object -ReferenceObject $helpParamNames -DifferenceObject $commandParamNames).where({
		# 			$_.SideIndicator -eq '<='
		# 		}) | should benullorempty
		# 		}
		# 	}
			
		# 	it 'all command parameters have a help parameter defined' {
		# 		if ($commandParamNames) {
		# 		@(Compare-Object -ReferenceObject $helpParamNames -DifferenceObject $commandParamNames).where({
		# 			$_.SideIndicator -eq '=>'
		# 		}) | should benullorempty
		# 		}
		# 	}
		# }
	}
	
}