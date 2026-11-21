# v10 test: GRUB menu, light mode, Setup window, a real install to the VM disk,
# then boot the installed system from the disk.
param([string]$Tag = 'v10')
$env:VBOX_USER_HOME = 'D:\VirtualBox\config'
$vbm = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
$vm  = 'TwilightOS-Test'
$out = 'D:\Projects\novaos\out\screens'
New-Item -ItemType Directory -Force $out | Out-Null

function Shot($name) { & $vbm controlvm $vm screenshotpng "$out\$Tag-$name.png" *> $null; "shot $Tag-$name" }
function Keys([string[]]$codes) { & $vbm controlvm $vm keyboardputscancode @codes *> $null }
function SendText($text) { & $vbm controlvm $vm keyboardputstring $text *> $null }
function Run($cmd, $wait) { SendText $cmd; Keys @('1c','9c'); Start-Sleep $wait }
$AltF4 = @('38','3e','be','b8')
$Term  = @('1d','38','14','94','b8','9d')
$Tab   = @('0f','8f')
$Down  = @('e0','50','e0','d0')

Start-Sleep 4
Shot '01-grub-iso'
Keys $Down; Start-Sleep 1; Keys @('e0','48','e0','c8')     # show the selection moving, then back
Start-Sleep 150
Shot '02-desktop'

Keys $Term; Start-Sleep 7
Run 'twilightos-settings-helper dark-set off; sleep 3; twilightos-settings personalisation &' 10
Shot '03-light-settings'
Keys $AltF4; Start-Sleep 2
Run 'twilightos-settings-helper dark-set on; clear' 5

Run 'twilightos-setup &' 9
Shot '04-setup-welcome'
Keys $AltF4; Start-Sleep 2

# the real install, through the same backend the Setup window uses
Run 'sudo twilightos-install --list-disks' 3
Run 'echo tester | sudo twilightos-install --disk /dev/sda --user alex --fullname "Alex Doe" --hostname twilight-vm --timezone Asia/Kolkata --locale en_US.UTF-8 --keymap us' 3
# mirror progress to the serial port so this script can follow it
Run 'clear; while sleep 5; do echo "SETUP-PROGRESS $(cat /run/twilightos-install/progress)" | sudo tee /dev/ttyS0; done' 2
$serial = 'D:\VirtualBox\VMs\TwilightOS-Test\serial.log'
$deadline = (Get-Date).AddMinutes(30)
$last = ''
$shotMid = $false
do {
    Start-Sleep 15
    $m = Select-String -Path $serial -Pattern 'SETUP-PROGRESS (-?\d+)\|(.*)' | Select-Object -Last 1
    if ($m) { $last = $m.Matches[0].Groups[1].Value + '|' + $m.Matches[0].Groups[2].Value.Trim() }
    if (-not $shotMid -and $last -match '^(\d+)' -and [int]$Matches[1] -ge 30) { Shot '05-installing'; $shotMid = $true }
} while ((Get-Date) -lt $deadline -and $last -notmatch '^(100|-1)\|')
"install result: $last"
Keys @('1d','2e','ae','9d'); Start-Sleep 1                    # Ctrl+C the loop
Run 'sudo tail -n 25 /run/twilightos-install/install.log' 3
Shot '06-install-log'
if ($last -notmatch '^100\|') { "INSTALL FAILED"; exit 1 }

# boot the installed system: power off, eject the ISO, start from the disk
& $vbm controlvm $vm poweroff *> $null; Start-Sleep 5
& $vbm storageattach $vm --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive
& $vbm startvm $vm --type gui *> $null
Start-Sleep 5
Shot '07-grub-installed'
Start-Sleep 60
Shot '08-sddm-installed'
SendText 'tester'; Keys @('1c','9c'); Start-Sleep 60
Shot '09-desktop-installed'
Keys $Term; Start-Sleep 7
Run 'findmnt -no SOURCE,OPTIONS / | cut -c1-90; lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS /dev/sda; free -m | head -2' 4
Shot '10-installed-terminal'
"done"
