<# =========================
  Meget enkel Employee → AD sync (på dansk)
  - Sletter tidligere synkroniserede brugere, og genskaber dem fra DB
  - Begynder-venlig: ingen avancerede funktioner
  Infrastruktur:
    MySQL via pfSense WAN: 10.101.81.5:3306  (NAT → DB)
    WinRM via pfSense WAN: 10.101.81.5:5985  (NAT → DC 192.168.1.2)
  AD domæne: hotel.rimami.local (OU=Employees,DC=hotel,DC=rimami,DC=local)
========================= #>

# ---------- GRUNDLÆGGENDE KONFIG ----------
$MysqlExe  = "C:\Program Files\MySQL\MySQL Server 9.4\bin\mysql.exe"

# MySQL (pfSense WAN → NAT)
$DbHost    = "10.101.81.5"
$DbPort    = 3306
$DbUser    = "rimami"
$DbPass    = "Kode1234!"
$DbName    = "hotelrimami"

# WinRM til AD (pfSense WAN → NAT til DC)
$AdNatIp   = "10.101.81.5"   # pfSense WAN IP der NAT’er til DC
$WinRmPort = 5985            # HTTP WinRM

# AD målcontainer / UPN / standard
$AdUser     = "HOTEL\Administrator"
$TargetPath = "OU=Employees,DC=hotel,DC=rimami,DC=local"   # <- OU (ikke CN)
$UpnSuffix  = "hotel.rimami.local"
$DefaultPwd = "Kode1234!"   # brugere skal skifte ved første login

# ---------- HENT MEDARBEJDERE FRA DB ----------
$Sql = @"
SELECT
  employee_id,
  first_name,
  last_name,
  email,
  role,
  1 AS active
FROM Employees
ORDER BY last_name, first_name;
"@

Write-Host "Henter medarbejdere fra MySQL..."
try {
  $raw = & $MysqlExe -h $DbHost -P $DbPort -u $DbUser --password="$DbPass" `
         --protocol=TCP -B -N $DbName -e $Sql 2>&1
  if ($LASTEXITCODE -ne 0) { throw [string]$raw }
} catch {
  Write-Host "FEJL: mysql.exe fejlede. Tjek sti / loginoplysninger / netværk." -ForegroundColor Red
  Write-Host $_.Exception.Message
  return
}

if (-not $raw) {
  Write-Host "Ingen rækker returneret fra MySQL." -ForegroundColor Yellow
  return
}

# Parse TSV → simple objekter
$lines = $raw -split "`r?`n" | Where-Object { $_.Trim() -ne "" }
$employees = @()
foreach ($line in $lines) {
  $c = $line -split "`t"
  if ($c.Count -lt 6) { continue }
  $obj = New-Object PSObject
  $obj | Add-Member NoteProperty EmployeeId $c[0]
  $obj | Add-Member NoteProperty FirstName  $c[1]
  $obj | Add-Member NoteProperty LastName   $c[2]
  $obj | Add-Member NoteProperty Email      $c[3]
  $obj | Add-Member NoteProperty Role       $c[4]
  $obj | Add-Member NoteProperty Active     ([int]$c[5])
  $employees += $obj
}
if ($employees.Count -eq 0) {
  Write-Host "Ingen gyldige medarbejdere kunne parse’s." -ForegroundColor Yellow
  return
}

# ---------- BEKRÆFT DESTRUKTIV HANDLING ----------
$answer = Read-Host "Dette vil SLETTE tidligere synkroniserede brugere og genskabe dem fra databasen. Fortsæt? (j/n)"
if ($answer -ne 'j') {
  Write-Host "Annulleret."
  return
}

# ---------- FORBEREDELSE AF WINRM SESSION ----------
$AdNatIp = $AdNatIp.Trim()
if ([string]::IsNullOrWhiteSpace($AdNatIp)) {
  Write-Host "FEJL: AdNatIp er tom. Sæt `$AdNatIp til pfSense WAN IP (fx 10.101.81.5)." -ForegroundColor Red
  return
}
Write-Host ("Bruger AdNatIp={0}, Port={1}" -f $AdNatIp, $WinRmPort)

# TrustedHosts (best effort)
try {
  $th = (Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue).Value
  if ($th -notmatch [regex]::Escape($AdNatIp)) {
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value $AdNatIp -Force | Out-Null
  }
} catch { }

# Tjek reachability
try {
  Test-WSMan -ComputerName $AdNatIp -Port $WinRmPort -ErrorAction Stop | Out-Null
} catch {
  Write-Host ("FEJL: Kan ikke nå WinRM på {0}:{1}. Tjek pfSense NAT/firewall." -f $AdNatIp,$WinRmPort) -ForegroundColor Red
  return
}

# Credentials
$cred = Get-Credential -Message "Indtast domæne-admin til DC (fx HOTEL\Administrator)" -UserName $AdUser

# Åbn session
Write-Host "Åbner fjernsession til AD..."
try {
  $so = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
  $sess = New-PSSession -ComputerName $AdNatIp -Port $WinRmPort `
                        -UseSSL:$false -Authentication Negotiate `
                        -Credential $cred -SessionOption $so -ErrorAction Stop
} catch {
  Write-Host "FEJL: Kunne ikke oprette PSSession." -ForegroundColor Red
  Write-Host $_.Exception.Message
  return
}

# ---------- KØR SYNC PÅ AD SERVER ----------
$InitialPwdSecure = ConvertTo-SecureString $DefaultPwd -AsPlainText -Force

$report = Invoke-Command -Session $sess -ArgumentList $employees, $TargetPath, $UpnSuffix, $InitialPwdSecure `
  -ScriptBlock {
    param($Employees, $TargetPath, $UpnSuffix, $InitialPwdSecure)

    Import-Module ActiveDirectory -ErrorAction Stop

    # Bekræft at OU findes
    try { $null = Get-ADObject -Identity $TargetPath -ErrorAction Stop }
    catch { throw "Målstien findes ikke: '$TargetPath'. Brug 'OU=Employees,DC=hotel,DC=rimami,DC=local'." }

    $items    = @()
    $removed  = 0
    $created  = 0
    $disabled = 0

    function Get-UniqueSam($baseSam) {
      $sam = $baseSam; $i = 1
      while (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        $sam = "$baseSam$i"; $i++
      }
      return $sam
    }
    function Get-UniqueCn($baseCn, $ouDn) {
      $cn = $baseCn; $i = 2
      while (Get-ADObject -Filter "Name -eq '$cn'" -SearchBase $ouDn -SearchScope OneLevel -ErrorAction SilentlyContinue) {
        $cn = "$baseCn ($i)"; $i++
      }
      return $cn
    }

    # 1) Slet tidligere synkroniserede (tag i Description)
    Write-Host "Sletter tidligere synkroniserede brugere..."
    $old = Get-ADUser -Filter { Description -like "synkroniseret af employees.ps1*" } -Properties Description -ErrorAction SilentlyContinue
    foreach ($u in $old) {
      Remove-ADUser -Identity $u.DistinguishedName -Confirm:$false
      Write-Host "[SLETTET] $($u.SamAccountName) ($($u.Name))"
      $items += [pscustomobject]@{ Handling='SLETTET'; Sam=$u.SamAccountName; Navn=$u.Name; Rolle=''; Status='tidligere tag' }
      $removed++
    }

    # 2) Slet evt. mønster-brugere (fornavnsinitial + efternavn)
    $baseNames = @()
    foreach ($e in $Employees) {
      if (-not $e.FirstName -or -not $e.LastName) { continue }
      $fn = $e.FirstName.ToString()
      $ln = $e.LastName.ToString()
      if ($fn.Length -gt 0) {
        $base = ($fn.Substring(0,1) + $ln).ToLower()
        $base = ($base -replace '[^a-z0-9]', '')
        if ($base -and ($baseNames -notcontains $base)) { $baseNames += $base }
      }
    }

    foreach ($b in $baseNames) {
      $cand = Get-ADUser -LDAPFilter "(sAMAccountName=$b*)" -ErrorAction SilentlyContinue
      foreach ($u in $cand) {
        Remove-ADUser -Identity $u.DistinguishedName -Confirm:$false
        Write-Host "[SLETTET] $($u.SamAccountName) ($($u.Name)) matchede '$b*'"
        $items += [pscustomobject]@{ Handling='SLETTET'; Sam=$u.SamAccountName; Navn=$u.Name; Rolle=''; Status="mønster $b*" }
        $removed++
      }
    }

    # 3) Opret brugere igen (pæn CN + sæt DisplayName bagefter)
    Write-Host "Opretter brugere fra databasen..."
    foreach ($e in $Employees) {
      if (-not $e.FirstName -or -not $e.LastName) { continue }

      $fn = $e.FirstName.ToString().Trim()
      $ln = $e.LastName.ToString().Trim()

      # Base sam = fornavns-initial + efternavn
      $baseSam = ""
      if ($fn.Length -gt 0) { $baseSam = ($fn.Substring(0,1) + $ln).ToLower() }
      $baseSam = ($baseSam -replace '[^a-z0-9]', '')
      if ([string]::IsNullOrWhiteSpace($baseSam)) {
        Write-Host "[SPRING OVER] Kunne ikke danne sam for '$($e.FirstName) $($e.LastName)'"
        continue
      }

      $sam         = Get-UniqueSam $baseSam
      $baseCn      = "$fn $ln"
      $cn          = Get-UniqueCn  $baseCn $TargetPath
      $displayName = $baseCn
      $enabled     = ([int]$e.Active -eq 1)

      try {
        # Opret uden -DisplayName for maksimal kompatibilitet
        New-ADUser `
          -Name                  $cn `
          -GivenName             $fn `
          -Surname               $ln `
          -SamAccountName        $sam `
          -UserPrincipalName     ($sam + "@" + $UpnSuffix) `
          -EmailAddress          $e.Email `
          -Description           ("[" + $e.Role + "]") `
          -Enabled               $enabled `
          -AccountPassword       $InitialPwdSecure `
          -ChangePasswordAtLogon $true `
          -Path                  $TargetPath `
          -ErrorAction           Stop

        # Sæt DisplayName bagefter (kompatibelt på alle versioner)
        Set-ADUser -Identity $sam -Replace @{displayName = $displayName}

        $status = if ($enabled) { "Aktiv" } else { "Deaktiveret" }
        if (-not $enabled) { $disabled++ }
        $created++

        Write-Host "[OPRETTET] $sam ($displayName) Rolle=$($e.Role) Status=$status"
        $items += [pscustomobject]@{ Handling='OPRETTET'; Sam=$sam; Navn=$displayName; Rolle=$e.Role; Status=$status }
      }
      catch {
        Write-Host "[FEJL] Kunne ikke oprette '$displayName' i '$TargetPath' - $($_.Exception.Message)" -ForegroundColor Red
        $items += [pscustomobject]@{ Handling='FEJL'; Sam=$sam; Navn=$displayName; Rolle=$e.Role; Status='oprettelse fejlede' }
      }
    }

    [pscustomobject]@{
      Elementer    = $items
      Slettet      = $removed
      Oprettet     = $created
      Deaktiveret  = $disabled
    }
  }

# ---------- KLIENTOUTPUT ----------
Write-Host ""
Write-Host "=== RESULTAT (klient) ==="
if ($report -and $report.Elementer) {
  $report.Elementer | Select-Object Handling, Sam, Navn, Rolle, Status | Format-Table -AutoSize
} else {
  Write-Host "(Ingen ændringer rapporteret.)"
}
Write-Host ""
Write-Host ("Opsummering: Slettet={0} Oprettet={1} Deaktiveret={2}" -f $report.Slettet, $report.Oprettet, $report.Deaktiveret)
Write-Host "Færdig. (Luk session med: Remove-PSSession $sess )"
