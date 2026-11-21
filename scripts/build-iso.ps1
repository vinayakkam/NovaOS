<#
.SYNOPSIS
  Build the TwilightOS ISO from Windows using the WSL "archlinux" distro.
  The work dir stays on the WSL ext4 disk (fast); the ISO is written to <repo>\out on D:.
.EXAMPLE
  .\scripts\build-iso.ps1
  .\scripts\build-iso.ps1 -Nvidia
#>
param([switch]$Nvidia, [switch]$KeepWork, [string]$Distro = 'archlinux')
$ErrorActionPreference = 'Stop'

$repo = Split-Path $PSScriptRoot -Parent
# D:\Projects\twilightos -> /mnt/d/Projects/twilightos
$drive = $repo.Substring(0,1).ToLower()
$wslRepo = "/mnt/$drive" + ($repo.Substring(2) -replace '\\','/')

$envs = @("OUT_DIR=$wslRepo/out")
if ($Nvidia)   { $envs += 'NVIDIA=1' }
if ($KeepWork) { $envs += 'KEEP_WORK=1' }

wsl.exe -d $Distro -u root -- env @envs bash "$wslRepo/scripts/build-iso.sh"
if ($LASTEXITCODE) { throw "ISO build failed (exit $LASTEXITCODE)" }
Get-ChildItem "$repo\out\*.iso" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 FullName, @{n='SizeGB';e={[math]::Round($_.Length/1GB,2)}}
