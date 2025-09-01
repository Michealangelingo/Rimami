# Filer og Mapper:

# 1. Windows: Opret en mappe på C-drevet.
mkdir "C:\Program Files\test"


# Tjenester:

# 2. Windows: Få en liste over alle tjenester på systemet.
Get-Service


# Brugere og Grupper:

# 3. Windows: Opret en ny bruger på systemet.
New-LocalUser -Name "username" -Password (Read-Host -AsSecureString "Skriv password")


# Automatisering med Scripts:

# 4. Windows: Opret et script til at sikkerhedskopiere en mappe til en bestemt placering.
$source = "originalmappe"
$destination = "Destinationsmappe"
Copy-Item $source $destination -Recurse


# Netværksadministration:

# 5. Windows: Få en liste over netværksforbindelser.
Get-NetAdapter


# Sikkerhed og Politikker:

# 6. Windows: Skift eksekveringspolitikken for PowerShell.
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser


# Remote Administration:

# 7. Windows: Opret en forbindelse til en fjerncomputer ved hjælp af PowerShell Remoting.
Enter-PSSession -ComputerName [computernavn] -Credential [bruger]


# Softwareadministration:

# 8. Windows: Få en liste over installeret software på systemet.
Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion



# Fejlfinding:

# 9. Windows: Få en liste over fejlhændelser i Event Log.
Get-EventLog -LogName Application -Newest 20


# Automatisk opdatering af software:

# 10. Windows: Opret en planlagt opgave for at opdatere specifik software regelmæssigt.
$action = New-ScheduledTaskAction
-Execute "winget.exe" -Argument
"upgrade --all"
$trigger = New-ScheduledTaskTrigger
-Daily -At 9am
Register-ScheduledTask -TaskName
"WingetUpgradeAll" -Action $action
-Trigger $trigger



# Harddiskadministration:

# 11. Windows: Få en liste over harddiske og deres størrelser.
Get-PhysicalDisk | Select-Object Friendlyname, Size


# Active Directory Administration:

# 12. Windows: Få en liste over brugere i Active Directory.
Get-ADUser -Filter * | Select-Object Name


# WMI (Windows Management Instrumentation):

# 13. Windows: Få systemoplysninger som f.eks. processorer og hukommelse.
Get-WmiObject Win32_Processor
Get-WmiObject Win32_PhysicalMemory


# Sikkerhedskopiering og gendannelse:

# 27. Windows: Opret en mappe til sikkerhedskopiering.
mkdir "D:\Backup"
