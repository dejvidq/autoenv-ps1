$ConfigPath = Join-Path -Path $HOME -ChildPath "autoenv"
$ConfigFile = Join-Path -Path $ConfigPath -ChildPath "autoenv.json"

function ConfigSetup() {
	<#
        .SYNOPSIS
        Setup autoenv configs
        .DESCRIPTION
        Setup autoenv configs. Create folder and config file if needed
        .EXAMPLE
        PS> ConfigSetup
    #>
    if (-not (Test-Path -Path $ConfigPath)) {
        New-Item $ConfigPath -ItemType directory | Out-Null
    }
    if (-not (Test-Path -Path $ConfigFile)) {
        New-Item $ConfigFile -ItemType file | Out-Null
    }
}

function ReadConfig() {
	<#
        .SYNOPSIS
        Read autoenv config file.
        .DESCRIPTION
        Read autoenv config file and return its content as hashtable
		.OUTPUTS
        System.Collections.Hashtable. ReadConfig returns a hashtable with the config content.
        .EXAMPLE
        PS> $Config = ReadConfig
        .EXAMPLE
        PS> ReadConfig
		
        Name                           Value
        ----                           -----
        C:\Projects\MyProject1         myEnv1
        C:\Projects\MyProject2         myEnv2
        C:\Projects\MyProject3         myEnv1
    #>
    $hashtable = Get-Content -Path $ConfigFile | ConvertFrom-Json -AsHashtable
    return $hashtable
}

function WriteConfig() {
	<#
        .SYNOPSIS
        Write config object to config file
        .DESCRIPTION
        Write config object content to the config file. Takes hastable with config content and writes to json config file
        .PARAMETER ConfigObject
        Hashtable with config content to write to file
		.EXAMPLE
        PS> WriteConfig -ConfigObject $Config
    #>
    param([hashtable]$ConfigObject)
    $ConfigObject | ConvertTo-Json | Out-File $ConfigFile
}

function SmartVenvActivate() {
	<#
        .SYNOPSIS
        Auto enable virtualenv in specific paths
        .DESCRIPTION
        Function automatically enables specific virtual env when entering specific paths added to config. Can be added to function overriding system Set-Location to work automatically
    #>
    $VirtualEnvs = ReadConfig
    $venvActivate = $false
    if ($VirtualEnvs.Count -gt 0) {
        foreach ($el in $VirtualEnvs.GetEnumerator()) {
            if (($pwd.Path).StartsWith($el.Key)) {
                $venvActivate = $true
                $currentEnv = $env:VIRTUAL_ENV
                if (!("$currentEnv" -eq "$(Join-Path -Path $el.Key -ChildPath $el.Value)")) {
                    $absolutePath = Resolve-Path -Path $(Join-Path -Path $ConfigPath -ChildPath $el.Value)
                    if ($PSVersionTable.Platform -eq "Win32NT") {
                        $pathToActivate = Join-Path -Path $absolutePath -ChildPath "Scripts" -AdditionalChildPath "Activate.ps1"
                    } else {
                        $pathToActivate = Join-Path -Path $absolutePath -ChildPath "bin" -AdditionalChildPath "Activate.ps1"
                    }
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
    <#
        .SYNOPSIS
        Create new autoenv.
        .DESCRIPTION
        Create new autoenv. Takes name of env to create and optionally different location than current one and different python than default
        .PARAMETER Name
        Virtualenv name to create
        .PARAMETER Python
        Python different than the default one
        .PARAMETER Location
        Location of the path to create autoenv for. By default it takes path where it's called
        .EXAMPLE
        PS> New-Autoenv -Name MyEnv
        .EXAMPLE
        PS> New-Autoenv -Name MyEnv -Location C:\Projects\MyProject
        .EXAMPLE
        PS> New-Autoenv -Name MyEnv -Location C:\Projects\MyProject -Python python3.10
        .EXAMPLE
        PS> New-Autoenv -Name MyEnv -Python python3.10
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [string]$Python = "python",
        [string]$Location = $PWD
    )
    $Python = $(Get-Command $Python)

    if (Test-Path -Path $Location) {
        $Location = Resolve-Path $Location
    } else {
        Write-Host "WARNING! Path: '$Location' does not exist. Using current path instead!" -ForegroundColor Yellow
        $Location = $PWD
    }
    # Remove trailing / if is passed in Location
    if (@("/", "\").Contains($Location.Substring($Location.get_Length() - 1))) {
        $Location = $Location.Substring(0, $Location.get_Length() - 1)
    }
    $CurrentConfig = ReadConfig
    & $Python -m venv $(Join-Path -Path $ConfigPath -ChildPath $Name)
    if ($CurrentConfig.Length -eq 0) {
        $CurrentConfig = @{
            $Location = $Name
        }
    } else {
        $CurrentConfig[$Location] = $Name
    }
    WriteConfig -ConfigObject $CurrentConfig
}

function Set-Autoenv() {
    <#
        .SYNOPSIS
        Add existing autoenv for new location
        .DESCRIPTION
        Add existing autoenv for new location. Takes name of the existing env and optionally different location than current one
        .PARAMETER Name
        Name of the existing autoenv
        .PARAMETER Location
        Location of the path to assign autoenv for. By default it takes current location
        .EXAMPLE
        PS> Set-Autoenv -Name MyEnv
        .EXAMPLE
        PS> Set-Autoenv -Name MyEnv -Location C:\Projects\MyProject
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [string]$Location = $PWD
    )

    $CurrentConfig = ReadConfig
    if (Test-Path -Path $(Join-Path -Path $ConfigPath -ChildPath $Name)) {
        $CurrentConfig[$Location] = $Name
    } else {
        Write-Host "There isn't virtualenv with name: '$Name'!" -ForegroundColor Red
    }
    WriteConfig -ConfigObject $CurrentConfig
}

function Get-AutoenvConfig() {
	<#
        .SYNOPSIS
        Get autoenv config
        .DESCRIPTION
        Get autoenv config content as table.
        .EXAMPLE
        PS> Get-AutoenvConfig
				
        Location                       Name
        ----                           -----
        C:\Projects\MyProject1         myEnv1
        C:\Projects\MyProject2         myEnv2
        C:\Projects\MyProject3         myEnv1
    #>
    $CurrentConfig = ReadConfig
    if ($CurrentConfig.Length -gt 0) {
        $CurrentConfig | Format-Table @{L = "Location"; E = "Name" }, @{L = "Name"; E = "Value" } -AutoSize
    } else {
        Write-Host "There are no virtualenvs created using autoenv" -ForegroundColor Yellow
    }
}

function Get-AllAutoenv() {
	<#
        .SYNOPSIS
        Get all virtualenvs created with autoenv
        .DESCRIPTION
        Get all virtualenvs created with autoenv. Returns all virtualenvs, each in new line
        .EXAMPLE
        PS> Get-AllAutoenv
		myEnv1
		myEnv2
		myEnv3
    #>
    foreach ($venv in $(Get-ChildItem -Directory -Name $ConfigPath)) {
        Write-Host "$venv" -ForegroundColor Green
    }
}

function Remove-Autoenv() {
    <#
        .SYNOPSIS
        Remove existing autoenv
        .DESCRIPTION
        Remove existing autoenv. Takes either Name or Location as string to remove it.
        .PARAMETER Name
        Virtualenv name to remove. It will remove virtualenv itself and all links to it for locations
        .PARAMETER Location
        Location of the path to remove autoenv. Removes this location from config but virtualenv itself is not removed.
        .EXAMPLE
        PS> Remove-Autoenv -Name MyEnv1
        .EXAMPLE
        PS> Remove-Autoenv -Location C:\Projects\MyProject
    #>
    param(
        [string]$Name,
        [string]$Location
    )

    $VenvPath = $(Join-Path -Path $ConfigPath -ChildPath $Name)
    if (($Name.Length -gt 0) -and (Test-Path -Path $VenvPath)) {
        $confirmation = Read-Host "Virtual env '$Name' will be removed for all locations! Are you sure? [y/n]"
        if ($confirmation -eq "y") {
            Remove-Item -Path $VenvPath -Force -Recurse
            Remove-VenvFromConfigByName -Name $Name
        }
    } elseif ($Location.Length -gt 0) {
        Remove-VenvFromConfigByLocation -Location $Location
    }

}

function Remove-VenvFromConfigByName() {
	<#
        .SYNOPSIS
        Remove existing autoenv from config by its name
        .DESCRIPTION
        Remove existing autoenv from config by name. Takes Name parameter and removes all paths from config assigned to that venv.
        .PARAMETER Name
        Virtualenv name to remove from config.
        .EXAMPLE
        PS> Remove-VenvFromConfigByName -Name MyEnv1
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    $Config = ReadConfig
    $PathsWithVirtualEnv = [System.Collections.ArrayList]@()
    foreach ($item in $Config.GetEnumerator()) {
        if ($item.Value -eq $Name) {
            $PathsWithVirtualEnv.Add($item.Key)
        }
    }
    foreach ($VenvPath in $PathsWithVirtualEnv) {
        $Config.Remove($VenvPath)
    }
    WriteConfig -ConfigObject $Config
}

function Remove-VenvFromConfigByLocation() {
	<#
        .SYNOPSIS
        Remove existing autoenv for specific location
        .DESCRIPTION
        Remove existing autoenv for specific location. Takes location as parameter and removes virtualenv from auto enabling on that path
        .PARAMETER Location
        Location of the path to remove autoenv for. Removes this location from config but virtualenv itself is not removed.
        .EXAMPLE
        PS> Remove-VenvFromConfigByLocation -Location C:\Projects\MyProject
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Location
    )
    $Config = ReadConfig
    $Config.Remove($Location)
    WriteConfig -ConfigObject $Config
}

function Set-Location() {
    Microsoft.PowerShell.Management\Set-Location "$Args";
    SmartVenvActivate;
}

Set-Alias -Name setenv -Value Set-Autoenv
Set-Alias -Name newenv -Value New-Autoenv
Set-Alias -Name lsenv -Value Get-AllAutoenv
Set-Alias -Name lsenvconf -Value Get-AutoenvConfig
Set-Alias -Name rmenv -Value Remove-Autoenv

# Check if "z" is installed and if yes, add this functionality also to it
if (Get-Module -ListAvailable -Name z) {
	function z() {
		z\z "$Args"
		SmartVenvActivate;
	}

	function smart_cd() {
		z\cdX "$Args"
		SmartVenvActivate;
	}
	set-item alias:cd -Value smart_cd
}

# Run function for config setup on profile loading
ConfigSetup