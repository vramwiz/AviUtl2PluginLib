#requires -Version 7.0
param(
    [Parameter(Mandatory = $true)][string]$PipeName,
    [Parameter(Mandatory = $true)]
    [ValidateSet('status', 'document', 'update-layer', 'save', 'rename-file',
        'new-from-png', 'import-png', 'replace-png', 'move-layer', 'reorder-layer', 'swap-layers', 'delete-layer', 'create-group', 'select-part',
        'export', 'import', 'progress', 'cancel', 'undo', 'redo', 'recover')]
    [string]$Command,
    [string]$ArgsJson = '{}',
    [ValidateRange(1, 60000)][int]$TimeoutMs = 5000
)
$ErrorActionPreference = 'Stop'
$arguments = ConvertFrom-Json -InputObject $ArgsJson -AsHashtable
if ($arguments -isnot [System.Collections.IDictionary]) { throw 'ArgsJson must be a JSON object' }
$envelope = @{ schemaVersion = 1; requestId = [guid]::NewGuid().ToString(); command = $Command; args = $arguments }
$payload = [Text.Encoding]::UTF8.GetBytes(($envelope | ConvertTo-Json -Depth 32 -Compress))
if ($payload.Length -gt 60000) { throw 'Command exceeds 60000 UTF-8 bytes' }
$client = [IO.Pipes.NamedPipeClientStream]::new('.', $PipeName,
    [IO.Pipes.PipeDirection]::InOut, [IO.Pipes.PipeOptions]::Asynchronous)
$received = [IO.MemoryStream]::new()
try {
    $client.Connect($TimeoutMs)
    $client.ReadMode = [IO.Pipes.PipeTransmissionMode]::Message
    $write = $client.WriteAsync($payload, 0, $payload.Length)
    if (-not $write.Wait($TimeoutMs)) { throw 'Pipe write timed out' }
    [void]$write.GetAwaiter().GetResult()
    $buffer = [byte[]]::new(65536)
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        $remaining = [int]($TimeoutMs - $timer.ElapsedMilliseconds)
        if ($remaining -le 0) { throw 'Pipe response timed out' }
        $read = $client.ReadAsync($buffer, 0, $buffer.Length)
        if (-not $read.Wait($remaining)) { throw 'Pipe response timed out' }
        $count = $read.GetAwaiter().GetResult()
        if ($count -eq 0) { throw 'Incomplete pipe response' }
        $received.Write($buffer, 0, $count)
        if ($received.Length -gt 16MB) { throw 'Pipe response exceeds 16MB' }
    } until ($client.IsMessageComplete)
    $response = [Text.Encoding]::UTF8.GetString($received.ToArray()) | ConvertFrom-Json
    if ($response.requestId -ne $envelope.requestId) { throw 'Response requestId mismatch' }
    $response | ConvertTo-Json -Depth 32
    if (-not $response.ok) { throw $response.error.message }
} finally {
    $received.Dispose()
    $client.Dispose()
}
