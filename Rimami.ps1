# Filer og Mapper:

# 1. Windows: Opret en mappe på C-drevet.
mkdir "C:\Program Files\test"
# 2. Ubuntu: Opret en mappe i hjemmekataloget.

# Tjenester:

# 3. Windows: Få en liste over alle tjenester på systemet.
Get-Service
# 4. Ubuntu: Få en liste over kørende tjenester.

# Brugere og Grupper:

# 5. Windows: Opret en ny bruger på systemet.
New-LocalUser -Name "username" -Password (Read-Host -AsSecureString "Skriv password")
# 6. Ubuntu: Opret en ny bruger med "adduser" kommandoen.

# Automatisering med Scripts:

# 7. Windows: Opret et script til at sikkerhedskopiere en mappe til en bestemt placering.
$source = "originalmappe"
$destination = "Destinationsmappe"
Copy-Item $source $destination -Recurse
# 8. Ubuntu: Opret et bash-script til at arkivere en mappe.

# Netværksadministration:

# 9. Windows: Få en liste over netværksforbindelser.
Get-NetAdapter
# 10. Ubuntu: Vis netværkskonfigurationen med "ifconfig" eller "ip" kommando.

# Sikkerhed og Politikker:

# 11. Windows: Skift eksekveringspolitikken for PowerShell.
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
# 12. Ubuntu: Se sikkerhedspolitikker og firewall-regler.

# Remote Administration:

# 13. Windows: Opret en forbindelse til en fjerncomputer ved hjælp af PowerShell Remoting.
Enter-PSSession -ComputerName [computernavn] -Credential [bruger]
# 14. Ubuntu: Opret en SSH-forbindelse til en fjernserver.

# Softwareadministration:

# 15. Windows: Få en liste over installeret software på systemet.
Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion

# 16. Ubuntu: Vis en liste over installeret software med "dpkg" eller "apt".

# Fejlfinding:

# 17. Windows: Få en liste over fejlhændelser i Event Log.
Get-EventLog -LogName Application -Newest 20
# 18. Ubuntu: Se systemlogfiler med "journalctl" eller "dmesg".

# Automatisk opdatering af software:

# 19. Windows: Opret en planlagt opgave for at opdatere specifik software regelmæssigt.
$action = New-ScheduledTaskAction
-Execute "winget.exe" -Argument
"upgrade --all"
$trigger = New-ScheduledTaskTrigger
-Daily -At 9am
Register-ScheduledTask -TaskName
"WingetUpgradeAll" -Action $action
-Trigger $trigger

# 20. Ubuntu: Konfigurér automatiske opdateringer med "unattended-upgrades".

# Harddiskadministration:

# 21. Windows: Få en liste over harddiske og deres størrelser.
Get-PhysicalDisk | Select-Object Friendlyname, Size
# 22. Ubuntu: Vis harddiskinformation med "lsblk" eller "fdisk".

# Active Directory Administration:

# 23. Windows: Få en liste over brugere i Active Directory.
Get-ADUser -Filter * | Select-Object Name
# 24. Ubuntu: Vis brugerinformation med "id" kommando.

# WMI (Windows Management Instrumentation):

# 25. Windows: Få systemoplysninger som f.eks. processorer og hukommelse.
Get-WmiObject Win32_Processor
Get-WmiObject Win32_PhysicalMemory
# 26. Ubuntu: Vis CPU-oplysninger med "lscpu" kommando.

# Sikkerhedskopiering og gendannelse:

# 27. Windows: Opret en mappe til sikkerhedskopiering.
mkdir "D:\Backup"
# 28. Ubuntu: Opret en sikkerhedskopimappe