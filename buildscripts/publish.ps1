$ErrorActionPreference = 'Stop'

try {
	## Don't upload the build scripts and appveyor.yml to PowerShell Gallery
	$moduleFolderPath = "$env:APPVEYOR_BUILD_FOLDER\PSPostMan"
	$null = mkdir $moduleFolderPath

	$excludeFromPublish = @(
		'PSPostMan\\buildscripts'
		'PSPostMan\\appveyor\.yml'
		'PSPostMan\\\.git'
		'PSPostMan\\README\.md'
	)
	$exclude = $excludeFromPublish -join '|'
	Get-ChildItem -Path $env:APPVEYOR_BUILD_FOLDER -Recurse | where { $_.FullName -notmatch $exclude } | Copy-Item -Destination {Join-Path -Path $moduleFolderPath -ChildPath $_.FullName.Substring($env:APPVEYOR_BUILD_FOLDER.length)}

	## Publish module to PowerShell Gallery
	$publishParams = @{
		Path = $moduleFolderPath
		NuGetApiKey = $env:nuget_apikey
		Repository = 'PSGallery'
		Force = $true
		Confirm = $false
	}
	Publish-Module @publishParams

} catch {
	Write-Error -Message $_.Exception.Message
	$host.SetShouldExit($LastExitCode)
}