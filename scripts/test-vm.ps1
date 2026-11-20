<#
.SYNOPSIS
  Create (or replace) the "NovaOS-Test" VirtualBox VM with the newest ISO attached, then boot it.
  Everything lives on D: (VBOX_USER_HOME=D:\VirtualBox\config, VMs in D:\VirtualBox\VMs).
.EXAMPLE
  .\scripts\test-vm.ps1
  .\scripts\test-vm.ps1 -Iso D:\Projects\novaos\out\novaos-2026.11.20-x86_64.iso -NoStart
#>
param(
    [string]$Iso,
    [string]$VmName   = 'NovaOS-Test',
    [int]   $Cpus     = 4,
    [int]   $MemoryMB = 6144,
    [int]   $VramMB   = 128,
    [int]   $DiskGB   = 40,
    # VirtualBox 7.1+ refuses install dirs that normal users can write to (e.g. D:\Tools),
    # so the program lives in Program Files; VMs, disks and settings stay on D:.
    [string]$VBoxManage = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe',
    [string]$BaseFolder = 'D:\VirtualBox\VMs',
    [switch]$NoStart
)
$ErrorActionPreference = 'Stop'
$env:VBOX_USER_HOME = 'D:\VirtualBox\config'

if (-not (Test-Path $VBoxManage)) { throw "VBoxManage not found at $VBoxManage" }
$repo = Split-Path $PSScriptRoot -Parent
if (-not $Iso) {
    $Iso = Get-ChildItem "$repo\out\*.iso" -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $Iso -or -not (Test-Path $Iso)) { throw "No ISO found in $repo\out - run scripts\build-iso.ps1 first" }

function Invoke-VBox {
    & $VBoxManage @args
    if ($LASTEXITCODE) { throw "VBoxManage $($args -join ' ') failed (exit $LASTEXITCODE)" }
}

$vmDir = Join-Path $BaseFolder $VmName
$disk  = Join-Path $vmDir "$VmName.vdi"

# Replace an existing VM of the same name (powers it off, deletes it and its disk)
$existing = & $VBoxManage list vms | Where-Object { $_ -match ('^"' + [regex]::Escape($VmName) + '"') }
if ($existing) {
    Write-Host "Replacing existing VM $VmName"
    $state = & $VBoxManage showvminfo $VmName --machinereadable | Select-String '^VMState='
    if ("$state" -match 'running|paused|stuck') {
        & $VBoxManage controlvm $VmName poweroff | Out-Null
        Start-Sleep -Seconds 3
    }
    Invoke-VBox unregistervm $VmName --delete
}

Write-Host "Creating $VmName with $Iso"
Invoke-VBox createvm --name $VmName --ostype ArchLinux_64 --basefolder $BaseFolder --register
Invoke-VBox modifyvm $VmName `
    --firmware efi --cpus $Cpus --memory $MemoryMB --vram $VramMB `
    --graphicscontroller vmsvga --accelerate-3d off `
    --mouse usbtablet --nic1 nat --rtc-use-utc on `
    --audio-enabled on --audio-out on --clipboard-mode bidirectional `
    --boot1 dvd --boot2 disk --boot3 none --boot4 none
Invoke-VBox createmedium disk --filename $disk --size ($DiskGB * 1024) --format VDI --variant Standard
Invoke-VBox storagectl $VmName --name SATA --add sata --controller IntelAhci --portcount 2 --bootable on
Invoke-VBox storageattach $VmName --storagectl SATA --port 0 --device 0 --type hdd --medium $disk
Invoke-VBox storageattach $VmName --storagectl SATA --port 1 --device 0 --type dvddrive --medium $Iso

Get-ChildItem $vmDir | Select-Object Name, @{n='MB';e={[math]::Round($_.Length/1MB,1)}} | Format-Table -AutoSize

if (-not $NoStart) { Invoke-VBox startvm $VmName --type gui }
