Param (
    # Versions to build in addition to the latest stable and beta, e.g. the AL compiler the NuGet package targets
    [string[]] $AdditionalVersions = @()
)

$PackageId = 'Microsoft.Dynamics.BusinessCentral.Development.Tools'

# Resolve latest version from NuGet flat container
$indexUrl = "https://api.nuget.org/v3-flatcontainer/$($PackageId.ToLower())/index.json"
try {
    $idx = Invoke-RestMethod -UseBasicParsing -Uri $indexUrl -Method GET -ErrorAction Stop
}
catch {
    throw "Failed to query NuGet index for '$PackageId'. $_"
}

$allVersions = @($idx.versions)
if (-not $allVersions -or $allVersions.Count -eq 0) {
    throw "No versions found for $PackageId."
}

# Find latest stable version (no suffix)
$stableVersions = $allVersions | Where-Object { $_ -notmatch '-' }
$latestStable = if ($stableVersions -and $stableVersions.Count -gt 0) { 
    $stableVersions[-1] 
}
else { 
    $null 
}

# Find latest beta version
$betaVersions = $allVersions | Where-Object { $_ -match '-beta' }
$latestBeta = if ($betaVersions -and $betaVersions.Count -gt 0) { 
    $betaVersions[-1] 
}
else { 
    $null 
}

# Build output array
$results = @()

if ($latestStable) {
    $stableSource = "https://api.nuget.org/v3-flatcontainer/$($PackageId.ToLower())/$latestStable/$($PackageId.ToLower()).$latestStable.nupkg"
    $results += [PSCustomObject]@{
        version = $latestStable
        source  = $stableSource
        type    = 'NuGetPackage'
    }
}

if ($latestBeta) {
    $betaSource = "https://api.nuget.org/v3-flatcontainer/$($PackageId.ToLower())/$latestBeta/$($PackageId.ToLower()).$latestBeta.nupkg"
    $results += [PSCustomObject]@{
        version = $latestBeta
        source  = $betaSource
        type    = 'NuGetPackage'
    }
}

foreach ($additionalVersion in $AdditionalVersions | Where-Object { $_ }) {
    if ($allVersions -notcontains $additionalVersion) {
        throw "Version '$additionalVersion' of $PackageId not found on NuGet."
    }
    if ($results.version -contains $additionalVersion) { continue }

    $results += [PSCustomObject]@{
        version = $additionalVersion
        source  = "https://api.nuget.org/v3-flatcontainer/$($PackageId.ToLower())/$additionalVersion/$($PackageId.ToLower()).$additionalVersion.nupkg"
        type    = 'NuGetPackage'
    }
}

Write-Output $results | ConvertTo-Json -Compress