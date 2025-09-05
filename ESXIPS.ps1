# ===== Config =====
$MysqlExe = "C:\Program Files\MySQL\MySQL Server 9.4\bin\mysql.exe"
$DbHost   = "10.101.81.5"
$DbPort   = 3306
$DbUser   = "rimami_admin"
$DbPass   = "Kode1234!"
$DbName   = "hotelrimami"

# ===== Query (Employees table; add synthetic 'active' column) =====
$query = @"
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

# ===== Run mysql and capture TSV (batch mode, no header) =====
try {
    $raw = & $MysqlExe -h $DbHost -P $DbPort -u $DbUser --password="$DbPass" `
           --protocol=TCP -B -N $DbName -e $query 2>$null
} catch {
    throw "mysql.exe execution failed. Check path/credentials/connectivity. $_"
}

if (-not $raw) {
    Write-Error "No rows returned (or query failed)."
    exit 1
}

# ===== Parse TSV to objects =====
$rows = $raw -split "`r?`n" | Where-Object { $_.Trim() }
$employees = foreach ($line in $rows) {
    $c = $line -split "`t"
    if ($c.Count -lt 6) { continue }
    [pscustomobject]@{
        EmployeeId = [int]$c[0]
        FirstName  = $c[1]
        LastName   = $c[2]
        Email      = $c[3]
        Role       = $c[4]
        Active     = [int]$c[5]
    }
}

# ===== Output =====
$employees | Sort-Object LastName, FirstName | Format-Table -AutoSize
Write-Host ""
Write-Host ("Total employees: {0}" -f ($employees.Count))
