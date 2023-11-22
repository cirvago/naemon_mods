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
# Note: Jobs without spaces in the name.
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
$RunIng = $job.IsRunning


if ($status -eq "Failed" -And $RunIng -ne "True" )
{
	Write-Host "CRITICAL! Errors were encountered during the job : $name.| veeam_daily=0;0;0;0"
	exit 2
}


if ($status -ne "Success" -And $RunIng -ne "True" )
{
	Write-Host "CRITICAL! Errors were encountered during the job: $name. | veeam_daily=0;0;0;0 "
	exit 2
}
	
# Veeam Backup & Replication job last run check

$now = (Get-Date).AddDays(-$period)
$now = $now.ToString("dd/MM/yyyy")
$last = Get-VBRJobScheduleOptions($job) | findstr LatestRunLocal
$last = $last -replace '.*LatestRunLocal * \: ', ''

if((Get-Date $now) -gt (Get-Date $last) -or $RunIng -ne "True" )
{
	Write-Host "CRITICAL! Last run of job: $name more than $period days ago. | veeam_daily=0;0;0;0 "
	exit 2
} 
else
{
    if (($job.info.LatestStatus) -eq "Success" )
        {
	        Write-Host "OK! Backup process of job $name completed successfully. | veeam_daily=1;0;0;1"
	        exit 0
        }
    if ($RunIng -eq "True" )
        {
            Write-Host "OK! Backup process of job $name  is Running. | veeam_daily=1;0;0;1"
	        exit 0
        }
    else
        {
            Write-Host "CRITICAL! Errors were encountered during the backup process of the following job: $name. | veeam_daily=0;0;0;0"
	    exit 2
        }
}
