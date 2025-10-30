# Astra Installer Script
# Downloads the specified version of Astra and installs it to the user's local bin directory
# Supported runtimes: luajit, luajit52, luau, lua51, lua52, lua53, lua54
# Default runtime: luajit

param(
    [string]$Runtime = "",
    [switch]$Help
)

# Function to display usage
function Show-Usage {
    Write-Host "Usage: $script:MyInvocation.MyCommand.Name [OPTIONS]"
    Write-Host "Options:"
    Write-Host "  -Runtime RUNTIME    Specify runtime (luajit, luajit52, luau, lua51, lua52, lua53, lua54)"
    Write-Host "  -Help               Show this help message"
    Write-Host ""
    Write-Host "Default runtime is luajit"
    exit 1
}

# Function to display runtime selection menu
function Select-Runtime {
    Write-Host "Please select a runtime for Astra:"
    Write-Host "1) luajit (default)"
    Write-Host "2) luajit52"
    Write-Host "3) luau"
    Write-Host "4) lua51"
    Write-Host "5) lua52"
    Write-Host "6) lua53"
    Write-Host "7) lua54"
    Write-Host ""
    
    do {
        $choice = Read-Host "Enter your choice (1-7) [1]"
        $choice = if ($choice -eq "") { 1 } else { $choice }
        
        switch ($choice) {
            1 { $script:Runtime = "luajit"; break }
            2 { $script:Runtime = "luajit52"; break }
            3 { $script:Runtime = "luau"; break }
            4 { $script:Runtime = "lua51"; break }
            5 { $script:Runtime = "lua52"; break }
            6 { $script:Runtime = "lua53"; break }
            7 { $script:Runtime = "lua54"; break }
            default {
                Write-Host "Invalid choice. Please try again."
                $choice = $null
            }
        }
    } while (-not $choice)
}

# Function to check if running with admin privileges
function Test-Admin {
    $currentUser = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Default runtime
if ($Runtime -eq "") {
    Select-Runtime
}

# If help is requested, show usage and exit
if ($Help) {
    Show-Usage
}

# Validate runtime
$ValidRuntimes = @("luajit", "luajit52", "luau", "lua51", "lua52", "lua53", "lua54")
$Valid = $false

foreach ($validRuntime in $ValidRuntimes) {
    if ($Runtime -eq $validRuntime) {
        $Valid = $true
        break
    }
}

if (-not $Valid) {
    Write-Error "Error: Invalid runtime '$Runtime'. Valid runtimes are: $($ValidRuntimes -join ', ')"
    exit 1
}

# Check for admin privileges
if (-not (Test-Admin)) {
    Write-Warning "This installer requires administrator privileges to properly set up the PATH environment variable."
    Write-Host "The installation will proceed but may not be able to update your PATH automatically."
    Write-Host "To ensure proper installation, please run this script as Administrator."
    Write-Host ""
    
    $continue = Read-Host "Do you want to continue with the installation? (y/n) [y]"
    if ($continue -eq "" -or $continue -eq "y" -or $continue -eq "Y") {
        Write-Host "Continuing with installation..."
    } else {
        Write-Host "Installation cancelled."
        exit 1
    }
}

# Configuration
$DownloadUrl = "https://github.com/ArkForgeLabs/Astra/releases/latest/download/astra-${Runtime}-windows-amd64.exe"
# For Windows, we'll install to a dedicated ArkForge directory
$InstallPath = "$env:USERPROFILE\AppData\Local\ArkForge\astra.exe"
$TempFile = "$env:TEMP\astra-${Runtime}-windows-amd64.exe"

Write-Host "Downloading Astra ${Runtime} binary..."
Write-Host "Runtime selected: ${Runtime}"

# Download the binary
try {
    Write-Host "Downloading from: $DownloadUrl"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempFile -ErrorAction Stop
    Write-Host "Download completed successfully"
} catch {
    Write-Error "Error: Failed to download Astra binary: $($_.Exception.Message)"
    exit 1
}

# Create directory if it doesn't exist
$installDir = [System.IO.Path]::GetDirectoryName($InstallPath)
if (-not (Test-Path $installDir)) {
    try {
        New-Item -ItemType Directory -Path $installDir -Force -ErrorAction Stop
        Write-Host "Created installation directory: $installDir"
    } catch {
        Write-Error "Error: Failed to create installation directory: $($_.Exception.Message)"
        exit 1
    }
}

# Install to the user's local bin directory
try {
    Move-Item -Path $TempFile -Destination $InstallPath -ErrorAction Stop
    Write-Host "Successfully installed Astra to: $InstallPath"
} catch {
    Write-Error ("Error: Failed to move binary to " + $InstallPath + ": " + $_.Exception.Message)
    exit 1
}

# Add the directory to PATH if it's not already there
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$arkforgePath = "$env:USERPROFILE\AppData\Local\ArkForge"
if ($currentPath -notlike "*$arkforgePath*") {
    try {
        $newPath = $currentPath + ";$arkforgePath"
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        Write-Host "Added $arkforgePath to your PATH environment variable"
        Write-Host "Please restart your terminal or run 'refreshenv' to apply the changes"
        Write-Host "You may also need to restart your shell or PowerShell session"
    } catch {
        Write-Warning "Warning: Failed to update PATH environment variable. You may need to add $arkforgePath manually to your PATH."
        Write-Host "To manually add to PATH:"
        Write-Host "1. Open System Properties (Win+R, type 'sysdm.cpl')"
        Write-Host "2. Go to Advanced tab > Environment Variables"
        Write-Host "3. Under 'User variables', select 'Path' and click 'Edit'"
        Write-Host "4. Add this path: $arkforgePath"
    }
} else {
    Write-Host "Path already in PATH environment variable"
}

Write-Host "Astra ${Runtime} has been successfully installed to $InstallPath"
Write-Host "You can now run 'astra' from anywhere in your terminal"

# Show a message about how to verify installation
Write-Host ""
Write-Host "To verify installation, open a new terminal and run:"
Write-Host "  astra --version"

# Show additional information
Write-Host ""
Write-Host "Installation completed successfully!"
Write-Host "For uninstallation, simply delete the file:"
Write-Host "  $InstallPath"