Clear-Host
Write-Host "Mod Analyzer" -ForegroundColor Yellow
Write-Host

Write-Host "Enter path to the mods folder: " -NoNewline
$mods = Read-Host "PATH"
Write-Host

if (-not $mods) {
    $mods = "$env:USERPROFILE\AppData\Roaming\.minecraft\mods"
	Write-Host "Continuing with " -NoNewline
	Write-Host $mods -ForegroundColor White
	Write-Host
}

if (-not (Test-Path $mods -PathType Container)) {
    Write-Host "Invalid Path!" -ForegroundColor Red
    exit 1
}

$process = Get-Process javaw -ErrorAction SilentlyContinue
if (-not $process) {
    $process = Get-Process java -ErrorAction SilentlyContinue
}

if ($process) {
    try {
        $startTime = $process.StartTime
        $elapsedTime = (Get-Date) - $startTime
    } catch {}

    Write-Host "{ Minecraft Uptime }" -ForegroundColor DarkCyan
    Write-Host "$($process.Name) PID $($process.Id) started at $startTime and running for $($elapsedTime.Hours)h $($elapsedTime.Minutes)m $($elapsedTime.Seconds)s"
    Write-Host ""
}

function Get-SHA1 {
    param (
        [string]$filePath
    )
    return (Get-FileHash -Path $filePath -Algorithm SHA1).Hash
}

function Fetch-Modrinth {
    param (
        [string]$hash
    )
    try {
        $response = Invoke-RestMethod -Uri "https://api.modrinth.com/v2/version_file/$hash" -Method Get -UseBasicParsing -ErrorAction Stop
		if ($response.project_id) {
            $projectResponse = "https://api.modrinth.com/v2/project/$($response.project_id)"
            $projectData = Invoke-RestMethod -Uri $projectResponse -Method Get -UseBasicParsing -ErrorAction Stop
            return @{ Name = $projectData.title; Slug = $projectData.slug }
        }
    } catch {}
	
    return @{ Name = ""; Slug = "" }
}

$verifiedMods = @()
$unknownMods = @()

$jarFiles = Get-ChildItem -Path $mods -Filter *.jar

$spinner = @("|", "/", "-", "\")
$totalMods = $jarFiles.Count
$counter = 0

foreach ($file in $jarFiles) {
	$counter++
	$spin = $spinner[$counter % $spinner.Length]
	Write-Host "`r[$spin] Scanning mods: $counter / $totalMods" -ForegroundColor Yellow -NoNewline
	
	$hash = Get-SHA1 -filePath $file.FullName
	
    $modDataModrinth = Fetch-Modrinth -hash $hash
    if ($modDataModrinth.Slug) {
		$verifiedMods += [PSCustomObject]@{ ModName = $modDataModrinth.Name; FileName = $file.Name }
		continue;
    }
	
	$unknownMods += [PSCustomObject]@{ FileName = $file.Name; FilePath = $file.FullName }
}

Write-Host "`r$(' ' * 80)`r" -NoNewline

if ($verifiedMods.Count -gt 0) {
	Write-Host "{ Verified Mods }" -ForegroundColor DarkCyan
	foreach ($mod in $verifiedMods) {
		Write-Host ("> {0, -30}" -f $mod.ModName) -ForegroundColor Green -NoNewline
		Write-Host "$($mod.FileName)" -ForegroundColor Gray
	}
	Write-Host
}

if ($unknownMods.Count -gt 0) {
	Write-Host "{ Unknown Mods }" -ForegroundColor DarkCyan
	foreach ($mod in $unknownMods) {
		Write-Host "> $($mod.FileName)" -ForegroundColor DarkYellow
	}
	Write-Host
}
