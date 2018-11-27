#        UPDProfileCheck
#
#   Author: Alexander A. Nordbø
#   alexander.a.nordbo@cegal.com
#   Special Thanks to Bobby @ Enterprise
#

Clear-Host

&{Clear-Variable a,b,c,d,x,y,z}
Write-Host "# For this script to work you have to run is as a domain administrator."
Write-Host "# You'll have to define a server with AD installed on it and a file server where UPD disks are stored." `n
Write-Host "NB! Remember to populate serverlist.txt with a list of RDS servers" -ForegroundColor Red `n
Write-Host "# ProfileHunter uses a custom algorithm to find inconsistencies between Active/Inactive UPD Disks and profiles on Servers."
Write-Host "# This will allow you to find and eliminate stuck profiles/UPD disks" `n `n

$FSSRV = Read-Host -Prompt 'File Server Hostname'

$ADSRV = Read-Host -Prompt 'Hostname of Host with AD'

$dir = $PSScriptRoot
$listpath = "$dir\serverlist.txt"

$Servers = Get-content $listpath
$Username = Read-Host -Prompt 'Input the user name'

$x = 0
$y = 0

Foreach ($Server in $Servers) {
$Test = Test-Path -path "\\$Server\c$\Users\$Username"
If ($Test -eq $True) {
Write-Host "User $Username exists on $Server" -ForegroundColor Green
$a = 1;$b = 1;$x = 1}
Else {
Write-Host "User $Username does NOT exist on $Server" -ForegroundColor Red
$b = 0;$a = 0;$y = 1}
}

if ($y -ne '1') {$y = 0}
if ($x -ne '1') {$x = 0}
$z = $x + $y

Invoke-Command -ComputerName $ADSRV -ScriptBlock {param ($Username) get-aduser $Username -properties * | select -property objectSid} -ArgumentList $Username | Select objectSid -ExcludeProperty RunspaceID, PSComputerName | ft -HideTableHeaders | Out-File "$dir\out.txt" -NoNewLine

".vhdx" | Out-File "$dir\out.txt" -Append -NoNewLine
$arg1 = Get-Content "$dir\out.txt"
$var1 = $arg1.split("-")[-1]

$arg2 = openfiles /query /S $FSSRV | ft | Out-File "$dir\openfiles.txt"

$arg3 = Get-Content -Path "$dir\openfiles.txt" | Where-Object { $_.Contains("$var1") }

if ($arg3 -like "*$var1") {
   Write-Host `n "UPD Active for user $Username" -ForegroundColor Green
   Write-Host `n "Active UPD Disks:" `n$arg3
   $c = 1;$d = 1
} Else {
   Write-Host `n "UPD Inactive for user $Username" -ForegroundColor Red
   $d = 0;$c = 0
}

function UPDHung {
   Write-Host `n "WARNING: UPD Disk is Active but profile on host(s) needs attention" -ForegroundColor Red
   $ans1 = Read-Host -Prompt 'Type "y" if you want to disconnect Connected UPD disks (ENTER to Exit)'
   if ($ans1 -eq "y") {
   $id = Read-Host -Prompt 'Type ID listed above:'
   openfiles /disconnect /S $FSSRV /id $id}
}

if ($a -eq '1' -And $c -eq '1') {Write-Host `n "User Logged in with status: OK" -ForegroundColor Green}
Elseif ($b -eq '0' -And $c -eq '0' -And $z -ne '2') {
   Write-Host `n "User Logged off with status: OK" `n -ForegroundColor Green
} Else {
    if ($z -gt '0' -And $d + $c -eq '0') {Write-Host "UPD Inactive but profile exists. Manually delete profile on server(s) listed above" -ForegroundColor Red}
    else { if ($d -gt $b) {UPDHung}
}}

$cleanup = "$dir\openfiles.txt","$dir\out.txt"
if (Test-Path $cleanup)
{
  Remove-Item $cleanup
}