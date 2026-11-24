#Requires -Version 7.2
param(
    [string] $Dart = 'dart',
    [ValidateRange(1, 3600)] [int] $TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$directory = Join-Path $root "build/test-results/$([guid]::NewGuid())"
[IO.Directory]::CreateDirectory($directory) | Out-Null
$resultPath = Join-Path $directory 'core.json'
$report = [ordered]@{
    profile = 'core'
    commit = git -C $root rev-parse HEAD
    status = 'configuration-error'
    checks = [Collections.Generic.List[object]]::new()
}
$exitCode = 3

function Invoke-DartCheck([string] $Name, [string[]] $Arguments) {
    $info = [Diagnostics.ProcessStartInfo]::new($dartExecutable)
    $info.WorkingDirectory = Join-Path $root 'core'
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.Environment['DART_SUPPRESS_ANALYTICS'] = 'true'
    foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($info)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $timedOut = !$process.WaitForExit($TimeoutSeconds * 1000)
        if ($timedOut -and !$process.HasExited) { $process.Kill($true) }
        $process.WaitForExit()
        $log = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
        [IO.File]::WriteAllText((Join-Path $directory "$Name.log"), $log)
        $report.checks.Add(@{ name = $Name; exitCode = $process.ExitCode; timedOut = $timedOut })
        if ($log.Trim()) { Write-Host $log.TrimEnd() }
        if ($timedOut) { throw [TimeoutException]::new("$Name timed out.") }
        return @{ Code = $process.ExitCode; Log = $log }
    }
    finally {
        $process.Dispose()
    }
}

try {
    $sdk = Get-Content -Raw (Join-Path $PSScriptRoot 'sdk.json') | ConvertFrom-Json
    $dartExecutable = (Get-Command $Dart -CommandType Application | Select-Object -First 1).Source
    $version = Invoke-DartCheck 'sdk' @('--version')
    $report.dart = $version.Log.Trim()
    if ($version.Code -ne 0 -or $report.dart -notmatch "^Dart SDK version: $([regex]::Escape($sdk.dart)) \(stable\)") {
        throw "Dart stable $($sdk.dart) is required."
    }
    $report.status = 'infrastructure-error'
    $exitCode = 2
    if ((Invoke-DartCheck 'dependencies' @('pub', 'get', '--offline', '--enforce-lockfile')).Code -ne 0) {
        throw 'Could not resolve the locked dependencies.'
    }
    foreach ($check in @(
        @{ Name = 'format'; Arguments = @('format', '--output=none', '--set-exit-if-changed', '.') },
        @{ Name = 'analyze'; Arguments = @('analyze', '--fatal-infos', '.') },
        @{ Name = 'core'; Arguments = @('run', 'test/chronicle_check.dart', $resultPath) }
    )) {
        if ((Invoke-DartCheck $check.Name $check.Arguments).Code -ne 0) {
            $report.status = 'failed'
            $exitCode = 1
            throw "$($check.Name) failed."
        }
    }
    $tests = Get-Content -Raw -LiteralPath $resultPath | ConvertFrom-Json
    foreach ($field in @('total', 'passed', 'failed', 'skipped')) {
        $value = $tests.$field
        if (($value -isnot [int] -and $value -isnot [long]) -or $value -lt 0) {
            throw "Invalid result field: $field."
        }
    }
    if ($tests.total -lt 1 -or $tests.total -ne ($tests.passed + $tests.failed + $tests.skipped)) {
        throw 'Invalid test totals.'
    }
    $report.tests = $tests
    if ($tests.failed -gt 0 -or $tests.skipped -gt 0) {
        $report.status = 'failed'
        $exitCode = 1
        throw 'Core checks failed or were skipped.'
    }
    $report.status = 'passed'
    $exitCode = 0
}
catch {
    if ($_.Exception -is [TimeoutException]) {
        $report.status = 'infrastructure-error'
        $exitCode = 2
    }
    $report.error = $_.Exception.Message
    Write-Host $report.error
}
finally {
    $report.exitCode = $exitCode
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $directory 'summary.json') -Encoding utf8
    Write-Host "Test profile: core. Report: $directory"
}
exit $exitCode
