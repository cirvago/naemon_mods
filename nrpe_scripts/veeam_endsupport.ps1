# Power By: C_V
# Date: Noviembre 2023
#PowerShell
##### Add scripts
# 1) 
# [/settings/external scripts/scripts]
# veeam_endsupport = cmd /c  echo scripts/veeam_endsupport.ps1 $ARG1$ $ARG2$ ; exit $LastExitCode | powershell.exe -command -
# ARG1: Days for warning
# ARG2: Days for critical
# 2) Naemon / Nagios
# check_nrpe  -t 30 -u -H 1$HOSTNAME$ -2 -c veeam_endsupport -a $ARG1$ $ARG2$
# Command

# Check expiration support expiration date.

#Global variables: pass days to Warning and critical

$dwarning = $args[0]
$dcritical = $args[1]


$now = (Get-Date).AddDays(-$period)
$now = $now.ToString("dd/MM/yyyy")
$EndSupp = Get-VBRInstalledLicense | findstr SupportExpirationDate
$EndSupp = $EndSupp -replace '.*SupportExpirationDate * \: ', ''
$DRest = New-TimeSpan -Start $now -End $EndSupp

if($Drest.Days -le $dcritical )
{
	Write-Host "CRITICAL!  $($Drest.Days.ToString()) to expire Support"
	exit 2
} 
if($Drest.Days -le $dwarning )
{
	Write-Host "WARNING! $($Drest.Days.ToString()) to expire Support."
	exit 1
} 
else
{
	Write-Host "OK! $($Drest.Days.ToString()) to expire Support"
	exit 0
}
