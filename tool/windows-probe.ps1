param(
    [Parameter(Mandatory = $true)] [string] $PackageDirectory,
    [Parameter(Mandatory = $true)] [string] $EvidenceDirectory
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

$package = (Resolve-Path -LiteralPath $PackageDirectory).Path
$evidence = (New-Item -ItemType Directory -Force -Path $EvidenceDirectory).FullName
$journal = Join-Path $evidence 'steps.txt'
$archive = Join-Path $package 'windows-probe.zip'
$expectedHash = (Get-Content -LiteralPath (Join-Path $package 'sha256.txt') -Raw).Trim()
$actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
if ($actualHash -ne $expectedHash) { throw 'Windows ZIP checksum mismatch.' }

$sandbox = (New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ('kronikas-windows-ui-' + [guid]::NewGuid()))).FullName
$executable = Join-Path $sandbox 'app/kronikas_platform_probe.exe'
$previousProbeHome = $env:KRONIKAS_PROBE_HOME
$app = $null

function Write-Step([string] $message) {
    Write-Host $message
    Add-Content -LiteralPath $journal -Value $message -Encoding utf8
}

function Get-ProbeWindow {
    $app.Refresh()
    if ($app.HasExited) { throw "Windows probe exited with code $($app.ExitCode)." }
    if ($app.MainWindowHandle -ne [IntPtr]::Zero) {
        [Windows.Automation.AutomationElement]::FromHandle($app.MainWindowHandle)
    }
}

function Wait-Label([string] $label) {
    $condition = New-Object Windows.Automation.PropertyCondition(
        [Windows.Automation.AutomationElement]::NameProperty, $label
    )
    $deadline = [Diagnostics.Stopwatch]::StartNew()
    while ($deadline.Elapsed.TotalSeconds -lt 30) {
        $window = Get-ProbeWindow
        if ($null -ne $window) {
            $element = $window.FindFirst([Windows.Automation.TreeScope]::Descendants, $condition)
            if ($null -ne $element) {
                Write-Step "Observed: $label"
                return $element
            }
        }
        Start-Sleep -Milliseconds 250
    }
    throw "UI state not observed: $label"
}

function Invoke-ProbeButton([string] $label) {
    $element = Wait-Label $label
    $pattern = $element.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern)
    Write-Step "Invoke: $label"
    $pattern.Invoke()
}

function Start-Probe {
    $script:app = Start-Process -FilePath $executable -WorkingDirectory (Split-Path -Parent $executable) -PassThru
    $null = Wait-Label 'Ready for synthetic probe.'
}

function Close-Probe {
    if ($app.HasExited) { throw 'Windows probe exited before the close step.' }
    if (!$app.CloseMainWindow() -or !$app.WaitForExit(10000)) {
        throw 'Windows probe did not close within 10 seconds.'
    }
    Write-Step 'Closed the Windows probe.'
}

try {
    Write-Step "Verified Windows ZIP SHA-256: $actualHash"
    Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $sandbox 'app')
    $env:KRONIKAS_PROBE_HOME = Join-Path $sandbox 'profile'
    Start-Probe
    Invoke-ProbeButton 'Save test data'
    $null = Wait-Label 'Synthetic chronicle and protected value saved.'
    Close-Probe
    Start-Probe
    Invoke-ProbeButton 'Verify saved data'
    $null = Wait-Label 'Chronicle and protected value verified.'
    Close-Probe
} catch {
    Write-Step "Failed: $($_.Exception.Message)"
    if ($null -ne $app -and !$app.HasExited) {
        try {
            $window = Get-ProbeWindow
            if ($null -ne $window) {
                $window.FindAll(
                    [Windows.Automation.TreeScope]::Descendants,
                    [Windows.Automation.Condition]::TrueCondition
                ) | ForEach-Object {
                    '{0} {1}' -f $_.Current.ControlType.ProgrammaticName, $_.Current.Name
                } | Set-Content -LiteralPath (Join-Path $evidence 'failure-ui.txt') -Encoding utf8
            }
        } catch {
            Write-Step "Could not collect the UI tree: $($_.Exception.Message)"
        }
    }
    throw
} finally {
    if ($null -ne $app -and !$app.HasExited) {
        Stop-Process -InputObject $app -Force -ErrorAction SilentlyContinue
    }
    $env:KRONIKAS_PROBE_HOME = $previousProbeHome
}
