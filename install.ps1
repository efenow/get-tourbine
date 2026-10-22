$ErrorActionPreference = 'Stop'

$Repository = 'https://github.com/efenow/tourbine'
$InstallDir = if ($env:TOURBINE_DIR) { $env:TOURBINE_DIR } else { Join-Path $HOME '.tourbine' }
$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('tourbine-install-' + [guid]::NewGuid())

function Fail([string]$Message) {
    Write-Error $Message
    exit 1
}

function Ask([string]$Message) {
    $answer = Read-Host "$Message [y/N]"
    return $answer -match '^[Yy]$'
}

Write-Host ''
Write-Host 'Tourbine installer' -ForegroundColor DarkYellow
Write-Host ''

Write-Host 'How would you like to install Tourbine?'
Write-Host '  1) Docker (recommended for servers and production)'
Write-Host '  2) npm (recommended for local development)'
$installMethod = Read-Host 'Choose [1/2]'
if ($installMethod -notin @('1', '2')) {
    Fail 'Choose 1 for Docker or 2 for npm.'
}

if ($installMethod -eq '1') {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) {
    if ((Get-Command winget -ErrorAction SilentlyContinue) -and (Ask 'Docker Desktop is missing. Install it with winget?')) {
        winget install --id Docker.DockerDesktop --exact --accept-package-agreements --accept-source-agreements
        Write-Host 'Docker Desktop installed. Start it, then run this installer again.' -ForegroundColor Yellow
        exit 0
    }

    Fail 'Docker Desktop is required: https://docs.docker.com/desktop/setup/install/windows-install/'
}

docker compose version *> $null
if ($LASTEXITCODE -ne 0) {
    Fail 'Docker Compose is unavailable. Update Docker Desktop and try again.'
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    $dockerDesktop = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
    if ((Test-Path $dockerDesktop) -and (Ask 'Docker Desktop is not running. Start it now?')) {
        Start-Process $dockerDesktop
        Write-Host 'Waiting for Docker Desktop...' -ForegroundColor DarkGray
        for ($i = 0; $i -lt 60; $i++) {
            Start-Sleep -Seconds 2
            docker info *> $null
            if ($LASTEXITCODE -eq 0) { break }
        }
    }

    docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        Fail 'Docker Desktop is not ready. Start it and run this installer again.'
    }
    }
}

New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
try {
    $composeFile = Join-Path $InstallDir 'docker-compose.yml'
    if ((Test-Path $composeFile) -or (Test-Path (Join-Path $InstallDir 'package.json'))) {
        Write-Host "Using existing Tourbine installation at $InstallDir" -ForegroundColor DarkGray
        if (Ask 'Update Tourbine source before building?') {
            $archive = Join-Path $TempDir 'tourbine.tar.gz'
            $source = Join-Path $TempDir 'source'
            Invoke-WebRequest "$Repository/archive/refs/heads/main.tar.gz" -OutFile $archive
            New-Item -ItemType Directory -Force -Path $source | Out-Null
            tar.exe -xzf $archive --strip-components=1 -C $source
            New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
            Copy-Item (Join-Path $source '*') $InstallDir -Recurse -Force
        }
    } else {
        $archive = Join-Path $TempDir 'tourbine.tar.gz'
        $source = Join-Path $TempDir 'source'
        Invoke-WebRequest "$Repository/archive/refs/heads/main.tar.gz" -OutFile $archive
        New-Item -ItemType Directory -Force -Path $source | Out-Null
        tar.exe -xzf $archive --strip-components=1 -C $source
        New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
        Copy-Item (Join-Path $source '*') $InstallDir -Recurse -Force
    }

    if ($installMethod -eq '2') {
        $node = Get-Command node -ErrorAction SilentlyContinue
        $npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
        if (-not $node) { Fail 'Node.js is required: https://nodejs.org/en/download' }
        if (-not $npm) { Fail 'npm is required: https://nodejs.org/en/download' }

        Push-Location $InstallDir
        try {
            Write-Host 'Installing npm dependencies...' -ForegroundColor DarkGray
            npm.cmd ci --omit=dev
            if ($LASTEXITCODE -ne 0) { Fail 'npm dependency installation failed.' }

            $env:NODE_ENV = 'production'
            $log = Join-Path $InstallDir 'tourbine.log'
            $errorLog = Join-Path $InstallDir 'tourbine-error.log'
            $process = Start-Process npm.cmd -ArgumentList 'start' -WorkingDirectory $InstallDir -RedirectStandardOutput $log -RedirectStandardError $errorLog -PassThru
            $process.Id | Set-Content (Join-Path $InstallDir 'tourbine.pid')
        } finally {
            Pop-Location
        }
    } else {
        Push-Location $InstallDir
        try {
            Write-Host 'Building and starting Tourbine...' -ForegroundColor DarkGray
            docker compose up -d --build
            if ($LASTEXITCODE -ne 0) {
                Write-Host 'Build failed. This may be a dependency conflict.' -ForegroundColor Red
                if (-not (Ask 'Retry with a fresh source download and no Docker cache?')) {
                    Fail 'Tourbine build failed.'
                }

                docker compose build --no-cache
                if ($LASTEXITCODE -ne 0) { Fail 'Tourbine no-cache build failed.' }
                docker compose up -d
                if ($LASTEXITCODE -ne 0) { Fail 'Tourbine failed to start.' }
            }
        } finally {
            Pop-Location
        }
    }
} finally {
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'Tourbine installed successfully.' -ForegroundColor Green
Write-Host 'Open http://localhost:3000' -ForegroundColor DarkGray
Write-Host "Path: $InstallDir" -ForegroundColor DarkGray
Write-Host 'Create your first admin account at /dashboard/setup.' -ForegroundColor DarkGray
