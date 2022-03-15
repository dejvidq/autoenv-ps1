# Autoenv
Autoenv automatically enables  Python virtualenv when you enter your project.
I handles both enter, and leave events.

## Requirements
PowerShell Core 

## Features
- Automatically enables and disables proper Python virtual env
- Create a new virtualenv for given path
- Add existing virtualenv for other paths
- Remove not needed virtualenv 
	- Remove whole virtualenv for all paths with virtualenv itself
	- Remove virtualenv for given path without removing whole virtualenv itself
- Print all created virtualenvs
- Print paths and virtualenvs linked to them

## Demo
[![asciicast](https://asciinema.org/a/476807.svg)](https://asciinema.org/a/476807)

## Instalation
1. Clone this repo or just copy content from [autoenv.ps1](autoenv.ps1) file and save it on your machine. 
2. Source [autoenv.ps1](autoenv.ps1) file in your `$PROFILE` file:
`. /path/to/autoenv.ps1`
3. Source your `$PROFILE` file or open your terminal again.

## Usage

| Command | Alias | Description |
|:---------:|:-------:|-------------|
|`New-Autoenv`|`newnev`|Create new autoenv. Takes name of env to create and optionally different location than current one and different python than default|
|`Set-Autoenv`|`setenv`|Add existing autoenv for new location. Takes name of the existing env and optionally different location than current one|
|`Remove-Autoenv`|`rmenv`|Remove existing autoenv. Takes either Name or Location as string to remove it. Removed either whole virtualenv with all links for paths or just virtualenv for given path leaving virtualenv created|
|`Get-AllAutoenv`|`lsenv`|Get all virtualenvs created with autoenv. Returns all virtualenvs, each in new line|
|`Get-AutoenvConfig`|`lsenvconfig`|Get autoenv config content as table.|

You can get help for each command with `Get-Help <command>`

## TODO
- [ ] Support for lower PowerShell versions
- [ ] Handle already existing virtualenvs outside autoenv folder without need of recreating them from scratch
- [ ] Change to module

## Known bugs
- [ ] When path for autoenv-virtualenv is nested under another path with another autoenv-virtualenv wrong virtualenv is enabled

