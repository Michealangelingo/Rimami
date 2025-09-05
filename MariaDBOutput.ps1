# ===== Config =====
$MysqlExe = "C:\Program Files\MySQL\MySQL Server 9.4\bin\mysql.exe"
$DbHost   = "10.101.81.5"      # use the IP your client can actually reach
$DbPort   = 3306
$DbUser   = "rimami_admin"
$DbPass   = "Kode1234!"
$DbName   = "hotelrimami"

# ===== Query (Employees table; synthesize 'active') =====
$query = @"
SELECT employee_id, first_name, last_name, email, role, 1 AS active
FROM Employees
ORDER BY last_name, first_name;
"@

# ===== Call mysql (DO NOT suppress stderr) =====
$mysqlArgs = @(
  '-h', $DbHost, '-P', $DbPort, '-u', $DbUser, "--password=$DbPass",
  '--protocol=TCP', '-B', '-N', $DbName, '-e', $query
)

$raw = & $MysqlExe @mysqlArgs 2>&1
$exit = $LASTEXITCODE
if ($exit -ne 0) {
  Write-Error "mysql.exe exit code: $exit"
  Write-Error "mysql.exe output:`n$raw"
  exit $exit
}
if (-not $raw) {
  Write-Error "Query returned zero rows."
  $cnt = & $MysqlExe -h $DbHost -P $DbPort -u $DbUser "--password=$DbPass" `
          --protocol=TCP -N -B $DbName -e "SELECT COUNT(*) FROM Employees;" 2>&1
  Write-Host "COUNT(Employees): $cnt"
  exit 1
}

# ===== Parse TSV and print =====
$rows = $raw -split "`r?`n" | Where-Object { $_.Trim() }
$employees = foreach ($line in $rows) {
  $c = $line -split "`t"; if ($c.Count -lt 6) { continue }
  [pscustomobject]@{
    EmployeeId = [int]$c[0]
    FirstName  = $c[1]
    LastName   = $c[2]
    Email      = $c[3]
    Role       = $c[4]
    Active     = [int]$c[5]
  }
}
$employees | Sort-Object LastName, FirstName | Format-Table -AutoSize
Write-Host ""
Write-Host ("Total employees: {0}" -f ($employees.Count))
