# ===== Config (edit if needed) =====
$MysqlExe = "C:\Program Files\MySQL\MySQL Server 9.4\bin\mysql.exe"
$DbHost   = "192.168.50.132"
$DbPort   = 3306
$DbUser   = "rimami_admin"
$DbPass   = "Kode1234!"
$DbName   = "rimami_cloud"

# ===== Query =====
$query = @"
SELECT employee_id, first_name, last_name, email, role, active
FROM employee
ORDER BY last_name, first_name;
"@

# ===== Run mysql and capture TSV (batch mode, no header) =====
try {
    $raw = & $MysqlExe -h $DbHost -P $DbPort -u $DbUser --password="$DbPass" `
           --protocol=TCP -B -N $DbName -e $query 2>$null
} catch {
    throw "mysql.exe execution failed. Check path/credentials/connectivity."
}

if (-not $raw) { Write-Error "No rows returned (or query failed)."; exit 1 }

# ===== Parse TSV to objects and output =====
$rows = $raw -split "`r?`n" | Where-Object { $_.Trim() }
$employees = foreach ($line in $rows) {
    $c = $line -split "`t"
    if ($c.Count -lt 6) { continue }
    [pscustomobject]@{
        EmployeeId = $c[0]
        FirstName  = $c[1]
        LastName   = $c[2]
        Email      = $c[3]
        Role       = $c[4]
        Active     = [int]$c[5]
    }
}

$employees | Sort-Object LastName, FirstName | Format-Table -AutoSize
Write-Host "`nTotal employees:" ($employees.Count)