# Rimami – MySQL → Active Directory Automatisering

Dette repository indeholder PowerShell-scripts, der henter medarbejderdata fra en MySQL-database og synkroniserer dem til Active Directory.

---

## Oversigt

- **`MariaDBOutput.ps1`**  
  Simpelt script der udtrækker medarbejdere fra databasen `hotelrimami` og viser dem i konsollen som tabel.

- **`SyncFraMariaDBTilActiveDirectory.ps1`**  
  Synkroniserer medarbejdere til AD:  
  - Sletter tidligere synkroniserede brugere.  
  - Opretter nye brugere med unikke brugernavne.  
  - Sætter *DisplayName*, UPN og rolle.  
  - Aktiverer/deaktiverer brugere baseret på kolonnen `active`.  

---

## Infrastruktur

- **Database:** MySQL tilgængelig via pfSense NAT  
  - Host: `10.101.81.5`  
  - Port: `3306`  
- **AD DC:** Tilgængelig via WinRM NAT  
  - Host: `10.101.81.5`  
  - Port: `5985`  
- **Domæne:** `hotel.rimami.local`  
  - OU: `OU=Employees,DC=hotel,DC=rimami,DC=local`

---

## Brug

### 1. Lav dataudtræk fra database  
```powershell
.\MariaDBOutput.ps1

### 2. Lav dataudtræk fra database samt oprettelse af brugere i Active Directory  
```powershell
.\SyncFraMariaDBTilActiveDirectory.ps1

