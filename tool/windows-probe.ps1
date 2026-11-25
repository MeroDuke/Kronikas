param(
    [Parameter(Mandatory = $true)] [string] $PackageDirectory,
    [Parameter(Mandatory = $true)] [string] $EvidenceDirectory,
    [switch] $StoryPicker
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName Accessibility
Add-Type -ReferencedAssemblies Accessibility -TypeDefinition (
    Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'windows-probe-accessible.cs')
)

$package = (Resolve-Path -LiteralPath $PackageDirectory).Path
$evidence = (New-Item -ItemType Directory -Force -Path $EvidenceDirectory).FullName
$journal = Join-Path $evidence 'steps.txt'
$archiveName = if ($StoryPicker) { 'windows-story-picker.zip' } else { 'windows-probe.zip' }
$archive = Join-Path $package $archiveName
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

function Get-ProbeElements {
    $app.Refresh()
    if ($app.HasExited) { throw "Windows probe exited with code $($app.ExitCode)." }
    if ($app.MainWindowHandle -ne [IntPtr]::Zero) {
        [ProbeAccessible]::Read($app.MainWindowHandle)
    }
}

function Wait-Label([string] $label) {
    $deadline = [Diagnostics.Stopwatch]::StartNew()
    $lastTransient = $null
    while ($deadline.Elapsed.TotalSeconds -lt 30) {
        try {
            foreach ($element in Get-ProbeElements) {
                if (($element.Name -split '\r?\n') -ccontains $label) {
                    Write-Step "Observed: $label"
                    return $element
                }
            }
        } catch {
            # A Flutter rebuild can invalidate a just-read MSAA node.
            $cause = $_.Exception
            while ($null -ne $cause -and $cause -isnot [Runtime.InteropServices.COMException]) {
                $cause = $cause.InnerException
            }
            if ($null -eq $cause -or $cause.HResult -notin @(-2147467259, -2147417848, -2147220995)) {
                throw
            }
            $lastTransient = $cause.Message
        }
        Start-Sleep -Milliseconds 250
    }
    if ($null -ne $lastTransient) { Write-Step "Last transient accessibility error: $lastTransient" }
    throw "UI state not observed: $label"
}

function Invoke-ProbeButton([string] $label) {
    $element = Wait-Label $label
    Write-Step "Invoke: $label"
    $element.Invoke()
}

function Start-Probe {
    $script:app = Start-Process -FilePath $executable -WorkingDirectory (Split-Path -Parent $executable) -PassThru
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
    if ($StoryPicker) {
        Invoke-ProbeButton 'Repó csatlakoztatása'
        Invoke-ProbeButton 'Teszt mese'
        Invoke-ProbeButton 'Mese szinkronizálása'
        $null = Wait-Label 'Helyi: Helyi átkelés'
        $null = Wait-Label 'Távoli: Távoli átkelés'
        Invoke-ProbeButton 'Helyi érték'
        Invoke-ProbeButton 'Feloldás mentése'
        $null = Wait-Label 'A feloldás mentve.'
        $null = Wait-Label 'Helyi átkelés'
    } else {
        $null = Wait-Label 'Ready for synthetic probe.'
        Invoke-ProbeButton 'Save test data'
        $null = Wait-Label 'Synthetic chronicle and protected value saved.'
        Close-Probe
        Start-Probe
        $null = Wait-Label 'Ready for synthetic probe.'
        Invoke-ProbeButton 'Verify saved data'
        $null = Wait-Label 'Chronicle and protected value verified.'
    }
    Close-Probe
} catch {
    Write-Step "Failed: $($_.Exception.Message)"
    if ($null -ne $app -and !$app.HasExited) {
        try {
            Get-ProbeElements |
                ForEach-Object { $_.Name } |
                Set-Content -LiteralPath (Join-Path $evidence 'failure-ui.txt') -Encoding utf8
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
