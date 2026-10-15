param(
    [Parameter(Mandatory = $true)]
    [string]$DestinationPath,

    [Parameter(Mandatory = $true)]
    [string]$ArchivePath,

    [Parameter(Mandatory = $true)]
    [string[]]$PathInArchive
)

# Always clean destination path
Remove-Item -Path $DestinationPath -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $DestinationPath | Out-Null

$archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)

try {
    # Use the first candidate subpath that exists in the archive (layouts differ between AL Language versions)
    $norm = $null
    foreach ($candidate in $PathInArchive) {
        # Normalize the archive subpath to ZIP's forward-slash form and ensure trailing slash
        $candidateNorm = ($candidate -replace '\\', '/').TrimStart('/')
        if ($candidateNorm.Length -gt 0 -and -not $candidateNorm.EndsWith('/')) { $candidateNorm += '/' }

        $exists = $archive.Entries | Where-Object {
            ($_.FullName -replace '\\', '/').StartsWith($candidateNorm, [StringComparison]::OrdinalIgnoreCase)
        } | Select-Object -First 1
        if ($exists) {
            $norm = $candidateNorm
            break
        }
    }
    if ($null -eq $norm) {
        throw "None of the paths '$($PathInArchive -join "', '")' found in archive '$ArchivePath'."
    }
    Write-Output "Extracting from path in archive: $norm"

    foreach ($entry in $archive.Entries) {
        $full = ($entry.FullName -replace '\\', '/')

        if (-not $full.StartsWith($norm, [StringComparison]::OrdinalIgnoreCase)) { continue }
        if ([string]::IsNullOrEmpty($entry.Name)) { continue } # directory pseudo-entries

        # Relative path after the given folder
        $rel = $full.Substring($norm.Length)

        # Guard against traversal
        if ($rel.Contains('..')) { continue }

        $destPath = Join-Path $DestinationPath ($rel -replace '/', '\')
        $destDir = Split-Path $destPath -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destPath, $true)
    }
}
finally {
    $archive.Dispose()
}