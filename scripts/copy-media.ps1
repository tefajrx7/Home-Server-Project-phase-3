Set-Alias oc "T:\HomeLab\bin\oc.exe"
$env:KUBECONFIG = "T:\HomeLab\auth\kubeconfig"
$srcRoot = "T:\Movies"
$stage = "T:\HomeLab\media-stage"

$free = (Get-PSDrive T).Free
Write-Host ("T: free GB: " + [math]::Round($free/1GB,1))
if ($free -lt 70GB) { Write-Host "STOP: T: free space is below 70 GB"; return }

New-Item -ItemType Directory -Force -Path $stage | Out-Null

function Get-Remote($n) {
  $o = oc exec -n media media-loader -- find "/media/$n" -type f -printf "%s\n" 2>$null
  if ($LASTEXITCODE -ne 0) { return $null }
  $a = @($o | Where-Object { $_ })
  $sum = 0
  foreach ($x in $a) { $sum += [int64]$x }
  return [pscustomobject]@{ Count = $a.Count; Bytes = $sum }
}

$report = @()
$items = Get-ChildItem -LiteralPath $srcRoot | Sort-Object { $_.PSIsContainer }
foreach ($item in $items) {
  $name = $item.Name -replace '[\[\]]', ''
  if ($item.PSIsContainer) {
    $lf = @(Get-ChildItem -LiteralPath $item.FullName -Recurse -File)
    $lCount = $lf.Count
    $lBytes = ($lf | Measure-Object Length -Sum).Sum
  } else {
    $lCount = 1
    $lBytes = $item.Length
  }
  $r = Get-Remote $name
  if ($r -ne $null -and $r.Count -eq $lCount -and $r.Bytes -eq $lBytes) {
    $status = "SKIP-already-complete"
  } elseif ($r -ne $null) {
    $status = "PARTIAL-or-different-check-manually"
  } else {
    if ($name -ne $item.Name) {
      $link = Join-Path $stage $name
      if (-not (Test-Path -LiteralPath $link)) {
        try { New-Item -ItemType HardLink -Path $link -Value $item.FullName -ErrorAction Stop | Out-Null }
        catch { Copy-Item -LiteralPath $item.FullName -Destination $link }
      }
      Set-Location -LiteralPath $stage
    } else {
      Set-Location -LiteralPath $srcRoot
    }
    Write-Host ("Copying: " + $name)
    oc cp $name "media/media-loader:/media/$name"
    $r2 = Get-Remote $name
    if ($r2 -ne $null -and $r2.Count -eq $lCount -and $r2.Bytes -eq $lBytes) { $status = "OK" } else { $status = "MISMATCH-or-missing" }
  }
  Write-Host ($status + " : " + $name)
  $report += [pscustomobject]@{ Name = $name; Status = $status; LocalGB = [math]::Round($lBytes/1GB,2) }
}
Set-Location T:\Movies
$report | Format-Table -AutoSize
Get-PSDrive T | Select-Object Used, Free
