param(
    [Parameter(Mandatory = $true)][string]$TemplatePath,
    [Parameter(Mandatory = $true)][string]$ConfigPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$template = [IO.File]::ReadAllText($TemplatePath)
$config = [IO.File]::ReadAllText($ConfigPath) | ConvertFrom-Json
$requiredNames = @(
    'banner',
    'objectName',
    'label',
    'information',
    'characterCaption',
    'moduleName'
)

foreach ($name in $requiredNames) {
    $property = $config.PSObject.Properties[$name]
    if (($null -eq $property) -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
        throw "Serif script setting '$name' is required: $ConfigPath"
    }
    $template = $template.Replace('{{' + $name + '}}', [string]$property.Value)
}

if ($template -match '\{\{[^}]+\}\}') {
    throw "An unresolved Serif script token remains in template: $($Matches[0])"
}

$additionalProperty = $config.PSObject.Properties['additionalScript']
if (($null -ne $additionalProperty) -and
    -not [string]::IsNullOrWhiteSpace([string]$additionalProperty.Value)) {
    $additionalPath = [string]$additionalProperty.Value
    if (-not [IO.Path]::IsPathRooted($additionalPath)) {
        $additionalPath = Join-Path (Split-Path -Parent $ConfigPath) $additionalPath
    }
    $template = $template.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine +
        [IO.File]::ReadAllText($additionalPath).TrimStart()
}

$outputDirectory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrEmpty($outputDirectory)) {
    [IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
}
$utf8WithoutBom = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($OutputPath, $template.TrimEnd() + [Environment]::NewLine, $utf8WithoutBom)
