$ProjectDir = "D:\Power BI\Weather Project\weather_forecast_accuracy_starter"
$PythonExe = Join-Path $ProjectDir ".venv\Scripts\python.exe"
$ScriptPath = Join-Path $ProjectDir "src\ingest_observations.py"
$LogDir = Join-Path $ProjectDir "logs"

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$LogFile = Join-Path $LogDir (
    "observations_" + (Get-Date -Format "yyyy-MM-dd") + ".log"
)

Set-Location $ProjectDir

"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Starting observation ingestion" |
    Out-File -FilePath $LogFile -Append -Encoding utf8

# Redirect Python output directly to the log to avoid PowerShell
# interpreting Python stderr messages as NativeCommandError records.
& $PythonExe -u $ScriptPath >> $LogFile 2>&1
$ExitCode = $LASTEXITCODE

"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Exit code: $ExitCode" |
    Out-File -FilePath $LogFile -Append -Encoding utf8

exit $ExitCode