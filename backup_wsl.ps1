# -----------------------------------------------------------------------------
# Script to export WSL distro to a VHDX file and log the process
# Should be run as Administrator, because of requiremets for Optimize-VHD

# -----------------------------------------------------------------------------
# settings
# -----------------------------------------------------------------------------

# WSL distro to be exported
$distroName = "Ubuntu" 

# output directories, target and temp
$tempDir = "c:\tmp"
$outputDir = "d:\valinor-wsl"

# Log file path with rotation based on the day of the week
$logFile = "$outputDir\backup-log.log"

# -----------------------------------------------------------------------------
function Write-Log {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Add-Content -Path $logFile -Value $logMessage
}

# -----------------------------------------------------------------------------
function Test-IsAdministrator {
    $currUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# -----------------------------------------------------------------------------
function Test-DockerRunning {
    $dockerStatus = docker desktop status 2>&1
    return $dockerStatus.Count -gt 1 -and $dockerStatus[1] -match "^Status\s+running"
}

# -----------------------------------------------------------------------------
function New-OutputDir {
    param (
        [string]$outputDir)

    if (-not (Test-Path -Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir | Out-Null
        Write-Log "Created output directory: $outputDir"
    }
}

# -----------------------------------------------------------------------------
function Stop-DockerDesktop {
    Write-Log "Checking if Docker Desktop is running..."

    if (Test-DockerRunning) {
        Write-Log "Docker Desktop is running. Attempting to shut it down..."
        docker desktop stop | Out-Null

        while (Test-DockerRunning) {
            Write-Log "Waiting for Docker Desktop to shut down..."
            Start-Sleep -Seconds 10
        }
        Write-Log "Docker Desktop has been shut down."
    }
    else {
        Write-Log "Docker Desktop is not running."
    }
}

# -----------------------------------------------------------------------------
function Stop-WSL {
    param (
        [string]$distroName = "Ubuntu" # Default WSL distro name to check
    )

    Write-Log "Stopping WSL..."
    wsl.exe --shutdown

    while (wsl.exe -l -v | Select-String -Pattern "^\s*$distroName\s+\d+\s+Running") {
        Write-Log "Waiting for WSL distro '$distroName' to stop..."
        Start-Sleep -Seconds 5
    }
    Write-Log "WSL has been stopped."
}

# -----------------------------------------------------------------------------
function Export-WSL {
    param (
        [string]$distroName,
        [string]$outputFile
    )

    Write-Log "Exporting WSL distro '$distroName' to '$outputFile'..."
    wsl.exe --export $distroName $outputFile --format vhd | Out-Null

    if ($?) {
        Write-Log "Export completed successfully."
    }
    else {
        Write-Log "Export failed."
        Exit 1
    }
}

# -----------------------------------------------------------------------------
function Optimize-BackupVHD {
    param (
        [string]$outputFile
    )

    Write-Log "Optimizing backup VHDX file '$outputFile'..."
    Optimize-VHD -Path $outputFile -Mode Full | Out-Null

    if ($?) {
        Write-Log "Optimization completed successfully."
    }
    else {
        Write-Log "Optimization failed."
        Exit 1
    }
}


# -----------------------------------------------------------------------------
# go johny go
# -----------------------------------------------------------------------------

Write-Log "-------------------------------------------------------"
Write-Log "Starting backup process for WSL distro '$distroName'..."

if (-not (Test-IsAdministrator)) {
    Write-Log "This script must be run as Administrator."
    Exit 1
}

$tmpFile = "$tempDir\$distroName.vhdx"
$outputFile = "$outputDir\$distroName.vhdx"

New-OutputDir -outputDir $outputDir
Stop-DockerDesktop
Stop-WSL -distroName $distroName 
Export-WSL -distroName $distroName -outputFile $tmpFile
Optimize-BackupVHD -outputFile $tmpFile

Write-Log "Moving backup file to final destination..."
Move-Item -Path $tmpFile -Destination $outputFile -Force

Write-Log "Backup process completed."
