<# =========================
  Employee sync via PSSession + Invoke-Command
  Output-upgraded: live lines + final table & summary
========================= #>

# ---------- CONFIG (LOCAL) ----------
$MysqlExe  = "C:\Program Files\MySQL\MySQL Server 9.4\bin\mysql.exe"
$DbHost    = "192.168.50.132"
$DbPort    = 3306
$DbUser    = "rimami_admin"
$DbPass    = "Kode1234!"
$DbName    = "rimami_cloud"

$AdEndpoint = "192.168.50.132"          # pfSense WAN -> NAT til DC 192.168.1.7
$AdUser     = "rimami\Administrator"
$TargetPath = "CN=Users,DC=rimami,DC=local"
$UpnSuffix  = "rimami.local"
$DefaultPwd = "Kode1234!"

# ---------- HENT DATA (LOCAL) ----------
$Sql = @"
SELECT employee_id, first_name, last_name, email, role, active
FROM employee;
"@

try {
  $raw = & $MysqlExe -h $DbHost -P $DbPort -u $DbUser --password="$DbPass" `
         --protocol=TCP -B -N $DbName -e $Sql 2>$null
} catch {
  throw "mysql.exe fejlede. Tjek sti/credentials/netværk."
}
if (-not $raw) { throw "Ingen rækker returneret (eller mysql fejlede)." }

# Parse TSV -> objects
$rows = $raw -split "`r?`n" | Where-Object { $_.Trim() }
$employees = foreach ($line in $rows) {
  $c = $line -split "`t"; if ($c.Count -lt 6) { continue }
  [pscustomobject]@{
    EmployeeId = $c[0]
    FirstName  = $c[1]
    LastName   = $c[2]
    Email      = $c[3]
    Role       = $c[4]
    Active     = [int]$c[5]
  }
}
if (-not $employees -or $employees.Count -eq 0) { throw "Ingen gyldige employee-rækker parse’t." }

# ---------- BEKRÆFT (LOCAL) ----------
$answer = Read-Host "Dette vil SLETTE tidligere synkroniserede brugere og genskabe dem fra databasen. Fortsæt? (j/n)"
if ($answer -ne 'j') { Write-Host "Annulleret."; return }

# ---------- SESSION (LOCAL) ----------
$sw = [System.Diagnostics.Stopwatch]::StartNew()
if (-not ($sess -and $sess.State -eq 'Opened')) {
  try { winrm quickconfig -q | Out-Null } catch {}
  try { Enable-PSRemoting -SkipNetworkProfileCheck -Force | Out-Null } catch {}
  try {
    $th = (Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue).Value
    if ($th -notmatch [regex]::Escape($AdEndpoint)) {
      Set-Item WSMan:\localhost\Client\TrustedHosts -Value $AdEndpoint -Force | Out-Null
    }
  } catch {}
  $cred = Get-Credential -Message "Angiv credentials til $AdEndpoint" -UserName $AdUser
  try {
    $global:sess = New-PSSession -ComputerName $AdEndpoint -Authentication Negotiate -Credential $cred -ErrorAction Stop
    Write-Host ("SESSION: OK -> Id={0} State={1} Computer={2}" -f $sess.Id,$sess.State,$sess.ComputerName)
  } catch {
    throw "Kunne ikke oprette PSSession til $AdEndpoint. $($_.Exception.Message)"
  }
} else {
  Write-Host ("SESSION: Genbruger eksisterende session Id={0} State={1} Computer={2}" -f $sess.Id,$sess.State,$sess.ComputerName)
}

# ---------- KØR REMOTE AD SYNC ----------
$InitialPwdSecure = ConvertTo-SecureString $DefaultPwd -AsPlainText -Force

$report = Invoke-Command -Session $sess -ArgumentList $employees, $TargetPath, $UpnSuffix, $InitialPwdSecure `
  -ScriptBlock {
    param($Employees, $TargetPath, $UpnSuffix, $InitialPwdSecure)

    Import-Module ActiveDirectory -ErrorAction Stop

    function New-Username {
      param($FirstName,$LastName)
      (($FirstName.Substring(0,1)+$LastName).ToLower() -replace '[^a-z0-9]','')
    }
    function Ensure-UniqueSam {
      param($Base)
      $u=$Base; $i=1
      while (Get-ADUser -Filter "SamAccountName -eq '$u'" -ErrorAction SilentlyContinue) { $u="$Base$i"; $i++ }
      $u
    }

    # Saml rapport-elementer
    $items    = New-Object System.Collections.ArrayList
    $removed  = 0
    $created  = 0
    $disabled = 0

    # Forbered sletning
    $baseSams = @()
    foreach ($e in $Employees) {
      if (-not $e.FirstName -or -not $e.LastName) { continue }
      $baseSams += (New-Username -FirstName $e.FirstName -LastName $e.LastName)
    }
    $baseSams = $baseSams | Select-Object -Unique

    # Slet tidligere taggede brugere
    $tagged = Get-ADUser -Filter { Description -like "synkroniseret af employees.ps1*" } -Properties Description,mail -ErrorAction SilentlyContinue
    $tagged | ForEach-Object {
      $info = "$($_.SamAccountName) ($($_.Name))"
      Remove-ADUser -Identity $_.DistinguishedName -Confirm:$false
      Write-Host "[FJERNET] $info (tidligere synkroniseret)."
      [void]$items.Add([pscustomobject]@{ Action='FJERNET'; Sam=$_.SamAccountName; Name=$_.Name; Role=''; Status=''; })
      $removed++
    }

    # Slet brugere der matcher datasættet
    foreach ($b in $baseSams) {
      Get-ADUser -LDAPFilter "(sAMAccountName=$b*)" -ErrorAction SilentlyContinue |
        ForEach-Object {
          $info = "$($_.SamAccountName) ($($_.Name))"
          Remove-ADUser -Identity $_.DistinguishedName -Confirm:$false
          Write-Host "[FJERNET] $info (matchede mønster '$b*')."
          [void]$items.Add([pscustomobject]@{ Action='FJERNET'; Sam=$_.SamAccountName; Name=$_.Name; Role=''; Status="mønster $b*"; })
          $removed++
        }
    }

    # Genopret brugere
    foreach ($e in $Employees) {
      if (-not $e.FirstName -or -not $e.LastName) { continue }
      $baseSam = New-Username -FirstName $e.FirstName -LastName $e.LastName
      $sam     = Ensure-UniqueSam -Base $baseSam

      $newUserParams = @{
        Name                  = $sam
        GivenName             = $e.FirstName
        Surname               = $e.LastName
        SamAccountName        = $sam
        UserPrincipalName     = "$sam@$UpnSuffix"
        EmailAddress          = $e.Email
        Description           = "synkroniseret af employees.ps1 [$($e.Role)]"
        Enabled               = ([int]$e.Active -eq 1)
        AccountPassword       = $InitialPwdSecure
        ChangePasswordAtLogon = $true
        Path                  = $TargetPath
      }

      New-ADUser @newUserParams
      $status = if ([int]$e.Active -eq 1) { "Aktiv" } else { "Deaktiveret" }
      if ($status -eq 'Deaktiveret') { $disabled++ }
      $created++

      Write-Host "[OPRETTET] Bruger $sam ($($e.FirstName) $($e.LastName)) – Rolle: $($e.Role) – Status: $status"
      [void]$items.Add([pscustomobject]@{
        Action='OPRETTET'; Sam=$sam; Name="$($e.FirstName) $($e.LastName)"; Role=$e.Role; Status=$status
      })
    }

    # Returnér samlet rapport til klienten
    [pscustomobject]@{
      Items    = $items
      Removed  = $removed
      Created  = $created
      Disabled = $disabled
    }
  }

$sw.Stop()

# ---------- KLIENT-OUTPUT: TABEL + SUMMARY ----------
Write-Host ""
Write-Host "=== RESULTAT (klient) ==="
if ($report -and $report.Items) {
  $table = $report.Items | Select-Object Action, Sam, Name, Role, Status
  $table | Format-Table -AutoSize
} else {
  Write-Host "(Ingen ændringer rapporteret fra serveren.)"
}

Write-Host ""
Write-Host ("Opsummering: Slettet={0}  Oprettet={1}  Deaktiveret={2}  (Tid: {3}s)" -f `
  $report.Removed, $report.Created, $report.Disabled, ([math]::Round($sw.Elapsed.TotalSeconds,2)) )

Write-Host "Færdig."

# Session bliver stående til genbrug. Luk selv med:  Remove-PSSession $sess
