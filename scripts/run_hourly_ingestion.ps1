
$ProjectDir = "D:\Power BI\Weather Project\weather_forecast_accuracy_starter"
$PythonExe = Join-Path $ProjectDir ".venv\Scripts\python.exe"
$ScriptPath = Join-Path $ProjectDir "src\ingest.py"
$LogDir = Join-Path $ProjectDir "logs"

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$LogFile = Join-Path $LogDir (
    "ingestion_" + (Get-Date -Format "yyyy-MM-dd") + ".log"
)

Set-Location $ProjectDir

"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Starting forecast ingestion" |
    Out-File -FilePath $LogFile -Append -Encoding utf8

$output = & $PythonExe -u $ScriptPath 2>&1
$ExitCode = $LASTEXITCODE

$output | Out-File -FilePath $LogFile -Append -Encoding utf8

"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Exit code: $ExitCode" |
    Out-File -FilePath $LogFile -Append -Encoding utf8

exit $ExitCode
