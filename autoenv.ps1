$ConfigPath = Join-Path -Path $HOME -ChildPath "autoenv"
$ConfigFile = Join-Path -Path $ConfigPath -ChildPath "autoenv.json"

function ConfigSetup() {
	if (-not (Test-Path -Path $ConfigPath)) {
		New-Item $ConfigPath -ItemType directory | Out-Null
	}
	if (-not (Test-Path -Path $ConfigFile)) {
		New-Item $ConfigFile -ItemType file | Out-Null
	}
}

function ReadConfig() {
	$hashtable = Get-Content -Path $ConfigFile | ConvertFrom-Json -AsHashtable
	return $hashtable
}

function WriteConfig() {
	param([hashtable]$ConfigObject)
	$ConfigObject | ConvertTo-Json | Out-File $ConfigFile
}

function smartVenvActivate() {
	$VirtualEnvs = ReadConfig
	$venvActivate = $false
	if ($VirtualEnvs.Count -gt 0) {
		foreach ($el in $VirtualEnvs.GetEnumerator()) {
			if (($pwd.Path).StartsWith($el.Key)) {
				$venvActivate = $true
				$currentEnv = $env:VIRTUAL_ENV
				if (!("$currentEnv" -eq "$(Join-Path -Path $el.Key -ChildPath $el.Value)")) {
					$absolutePath = Resolve-Path -Path $(Join-Path -Path $ConfigPath -ChildPath $el.Value)
					$pathToActivate = Join-Path -Path $absolutePath -ChildPath "Scripts" -AdditionalChildPath "activate.ps1"
					& "$pathToActivate"
				}
			}
		}
	}
	if ((-not $venvActivate) -and (($env:VIRTUAL_ENV).Length -gt 0)) {
		deactivate
	}
}

function New-Autoenv() {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Name,
		[string]$Python = "python",
		[string]$Location = $PWD
	)
	$Python = $(Get-Command $Python)

	if (Test-Path -Path $Location) {
		$Location = Resolve-Path $Location
	}
 else {
		Write-Host "WARNING! Path: '$Location' does not exist. Using current path instead!"
		$Location = $PWD
	}
	# Remove trailing / if is passed in Location
	if (@("/", "\").Contains($Location.Substring($Location.get_Length() - 1))) {
		$Location = $Location.Substring(0, $Location.get_Length() - 1)
	}
	$CurrentConfig = ReadConfig
	& $Python -m venv $(Join-Path -Path $ConfigPath -ChildPath $Name)
	$CurrentConfig += @{
		$Location = $Name
	}
	WriteConfig -ConfigObject $CurrentConfig
}

function Add-Autoenv() {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Name,
		[string]$Location = $PWD
	)

	$CurrentConfig = ReadConfig
	if (Test-Path -Path $(Join-Path -Path $ConfigPath -ChildPath $Name)) {
		$CurrentConfig[$Location] = $Name
	} else {
		Write-Host "There isn't virtualenv with name: '$Name'!"
	}
	WriteConfig -ConfigObject $CurrentConfig
}

function Read-AutoenvConfig() {
	$CurrentConfig = ReadConfig
	if ($CurrentConfig.Length -gt 0) {
		foreach ($venv in $CurrentConfig.GetEnumerator()) {
			Write-Host "$($venv.Value) -> $($venv.Key)"
		}
	} else {
		Write-Host "There are no virtualenvs created using autoenv"
	}
}

function Set-Location() {
	Microsoft.PowerShell.Management\Set-Location "$Args";
	smartVenvActivate;
}

Set-Alias -Name addenv -Value Add-Autoenv
Set-Alias -Name newenv -Value New-Autoenv

# Run function for config setup on profile loading
ConfigSetup