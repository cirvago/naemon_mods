# Change to: Veeam Backup and recovery v12
# Modify by: c_V   23 Oct 2023
# Script original: https://exchange.nagios.org/directory/Plugins/Backup-and-Recovery/Others/Veeam-Daily-Backup-Check/details
# owner: robinsmit
# website: www.robinsmit.nl
# Instruction:
# 1) run cmd with adminitrator
#     powershell.exe Set-ExecutionPolicy Bypass
# 2) 
# [/settings/external scripts/scripts]
# alias_daily_backup = cmd /c  echo scripts/veeam_daily_backup.ps1 $ARG1$ $ARG2$ ; exit $LastExitCode | powershell.exe -command -
# ARG1: Name Job whitout spaces
# ARG2: Days
# 3) Naemon / Nagios
# check_nrpe  -t 30 -u -H 1$HOSTNAME$ -2 -c alias_daily_backup -a $ARG1$ $ARG2$
# Command
# 

# Global variables
$name = $args[0]
$period = $args[1]

# Veeam Backup & Replication job status check

$job = Get-VBRJob -Name $name
$name = "'" + $name + "'"

if ($job -eq $null)
{
	Write-Host "UNKNOWN! No such a job: $name."
	exit 3
}

$status = $job.GetLastResult()


if ($status -eq "Failed")
{
	Write-Host "CRITICAL! Errors were encountered during the backup process of the following job: $name."
	exit 2
}


if ($status -ne "Success")
{
	Write-Host "WARNING! Job $name didn't fully succeed."
	exit 1
}
	
# Veeam Backup & Replication job last run check

$now = (Get-Date).AddDays(-$period)
$now = $now.ToString("dd/MM/yyyy")
$last = Get-VBRJobScheduleOptions($job) | findstr LatestRunLocal
$last = $last -replace '.*LatestRunLocal * \: ', ''

if((Get-Date $now) -gt (Get-Date $last))
{
	Write-Host "CRITICAL! Last run of job: $name more than $period days ago."
	exit 2
} 
else
{
	Write-Host "OK! Backup process of job $name completed successfully."
	exit 0
}
