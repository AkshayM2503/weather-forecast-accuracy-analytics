$ProjectDir = "D:\Power BI\Weather Project\weather_forecast_accuracy_starter"
$PythonExe = Join-Path $ProjectDir ".venv\Scripts\python.exe"
$ScriptPath = Join-Path $ProjectDir "src\verify_forecasts.py"
$LogDir = Join-Path $ProjectDir "logs"

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$LogFile = Join-Path $LogDir (
    "verification_" + (Get-Date -Format "yyyy-MM-dd") + ".log"
)

Set-Location $ProjectDir

"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Starting forecast verification" |
    Out-File -FilePath $LogFile -Append -Encoding utf8

& $PythonExe -u $ScriptPath >> $LogFile 2>&1
$ExitCode = $LASTEXITCODE

"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Exit code: $ExitCode" |
    Out-File -FilePath $LogFile -Append -Encoding utf8

exit $ExitCode