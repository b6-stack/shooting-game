# Samsung Galaxy S24+ ADB Push & Launch Script
# Usage: powershell -ExecutionPolicy Bypass -File scripts\push_to_s24.ps1

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  ShootingGame - Deploy to Samsung Galaxy S24+ / Android " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Locate ADB
$adb = "adb"
if (-not (Get-Command "adb" -ErrorAction SilentlyContinue)) {
    $fallbackAdb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $fallbackAdb) {
        $adb = $fallbackAdb
        Write-Host "[INFO] Using ADB from: $adb" -ForegroundColor Yellow
    } else {
        Write-Host "[ERROR] adb was not found in PATH or Android SDK platform-tools." -ForegroundColor Red
        Write-Host "Please ensure Android SDK platform-tools is installed." -ForegroundColor Red
        exit 1
    }
}

$apkPath = "$PSScriptRoot\..\build\android\ShootingGame_debug.apk"
if (-not (Test-Path $apkPath)) {
    Write-Host "[ERROR] APK file not found at: $apkPath" -ForegroundColor Red
    Write-Host "Please build the APK first." -ForegroundColor Red
    exit 1
}

$apkItem = Get-Item $apkPath
Write-Host ("[INFO] Target APK: {0} ({1:N2} MB)" -f $apkItem.Name, ($apkItem.Length / 1MB)) -ForegroundColor Green

# Query connected devices
Write-Host "[INFO] Checking connected ADB devices..." -ForegroundColor Cyan
$deviceLines = & $adb devices | Where-Object { $_ -match "\bdevice\b" -and $_ -notmatch "List of devices" }

if (-not $deviceLines) {
    Write-Host ""
    Write-Host "[!] No active Android device detected!" -ForegroundColor Yellow
    Write-Host "To connect your Samsung Galaxy S24+:" -ForegroundColor White
    Write-Host "  1. Connect your S24+ via USB-C cable (or ensure Wireless Debugging is on)." -ForegroundColor Gray
    Write-Host "  2. Go to: Settings -> About phone -> Software information -> Tap 'Build number' 7 times." -ForegroundColor Gray
    Write-Host "  3. Go to: Settings -> Developer options -> Enable 'USB debugging'." -ForegroundColor Gray
    Write-Host "  4. On your S24+ screen, accept the 'Allow USB debugging' prompt (check 'Always allow')." -ForegroundColor Gray
    Write-Host "  5. For Wireless Debugging, run: adb connect <PHONE_IP>:<PORT>" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Waiting for device to connect... (Press Ctrl+C to cancel)" -ForegroundColor Yellow
    & $adb wait-for-device
}

# Fetch device details
$deviceModel = (& $adb shell getprop ro.product.model).Trim()
$deviceManufacturer = (& $adb shell getprop ro.product.manufacturer).Trim()
$androidVer = (& $adb shell getprop ro.build.version.release).Trim()
$soc = (& $adb shell getprop ro.soc.model).Trim()

Write-Host ""
Write-Host "----------------------------------------------------------" -ForegroundColor Green
Write-Host " Connected Device: $deviceManufacturer $deviceModel" -ForegroundColor Green
Write-Host " Android Version:  Android $androidVer" -ForegroundColor Green
if ($soc) {
    Write-Host " Hardware / SoC:   $soc" -ForegroundColor Green
}
Write-Host "----------------------------------------------------------" -ForegroundColor Green

# Install APK
Write-Host "[1/2] Installing APK to device (-r reinstall)..." -ForegroundColor Cyan
$installResult = & $adb install -r $apkPath
Write-Host $installResult

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] APK installation failed. Check device storage and permissions." -ForegroundColor Red
    exit 1
}

# Launch Game Activity
Write-Host "[2/2] Launching ShootingGame on $deviceModel..." -ForegroundColor Cyan
& $adb shell am start -n com.antigravity.shootinggame/com.godot.game.GodotAppLauncher

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  SUCCESS! ShootingGame is running on your $deviceModel!  " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Tips for Galaxy S24+:" -ForegroundColor Cyan
Write-Host " - Screen runs at up to 120Hz native refresh rate (max_fps=0)." -ForegroundColor Gray
Write-Host " - 19.5:9 ultrawide viewport automatically expands edge-to-edge." -ForegroundColor Gray
Write-Host " - Touch controls and HUD adapt around the center punch-hole camera." -ForegroundColor Gray
