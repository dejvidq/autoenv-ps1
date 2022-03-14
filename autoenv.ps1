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

function SmartVenvActivate() {
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
    $CurrentConfig += @{
        $Location = $Name
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

function Read-AutoenvConfig() {
    $CurrentConfig = ReadConfig
    if ($CurrentConfig.Length -gt 0) {
        $CurrentConfig | Format-Table @{L = "Location"; E = "Name" }, @{L = "Name"; E = "Value" } -AutoSize
    } else {
        Write-Host "There are no virtualenvs created using autoenv" -ForegroundColor Yellow
    }
}

function Get-AllAutoenv() {
    $CurrentConfig = ReadConfig
    $VirtualEnvs = $CurrentConfig.Values | Select-Object -Unique
    foreach ($venv in $VirtualEnvs) {
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
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    $Config = ReadConfig
    $PathsWithVirtualEnv = [System.Collections.ArrayList]@()
    foreach ($item in $Config.GetEnumerator()) {
        if ($($item.Value) -eq $Name) {
            $PathsWithVirtualEnv.Add($item.Key)
        }
    }
    foreach ($VenvPath in $PathsWithVirtualEnv) {
        $Config.Remove($VenvPath)
    }
    WriteConfig -ConfigObject $Config
}

function Remove-VenvFromConfigByLocation() {
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
Set-Alias -Name lsenvconf -Value Read-AutoenvConfig
Set-Alias -Name rmenv -Value Remove-Autoenv

# Run function for config setup on profile loading
ConfigSetup