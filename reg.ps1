# 1. Admin Verification
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: You must run this script as ADMINISTRATOR!" -ForegroundColor Red
    Start-Sleep -s 5 ; Exit
}

Write-Host "--- ADVANCED WINDOWS PROCESS FORCER ---" -ForegroundColor Cyan

# --- STEP 1: EXE INFO ---
$exeName = Read-Host "Executable name (e.g., game.exe)"
if (-not $exeName.EndsWith(".exe")) { $exeName += ".exe" }

# --- STEP 2: PRIORITY ---
Write-Host "`nLevels: [1] Low | [2] Normal | [3] High | [4] REALTIME (Force Mode)"
$prioVal = Read-Host "Choice (1-4)"

# --- STEP 3: AFFINITY ---
$logicalCores = (Get-WmiObject Win32_Processor).NumberOfLogicalProcessors
Write-Host "`nYour PC has $logicalCores cores (0 to $(($logicalCores-1)))."
$coreInput = Read-Host "Core list (e.g., 0,1) or leave EMPTY to skip"

$affinityHex = ""
if (![string]::IsNullOrWhiteSpace($coreInput)) {
    $mask = 0
    $cores = $coreInput -split ","
    foreach ($c in $cores) { $mask += [long][Math]::Pow(2, [int]$c.Trim()) }
    $affinityHex = "0x{0:X}" -f $mask
}

# --- STEP 4: IMPLEMENTATION ---
$ifeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exeName"
$perfPath = "$ifeoPath\PerfOptions"
$silentExitPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$exeName"

# Clean start
if (!(Test-Path $perfPath)) { New-Item -Path $perfPath -Force | Out-Null }

if ($prioVal -eq "4") {
    # THE REALTIME TRICK (Your Debugger Method)
    Write-Host "Applying Realtime Force via Debugger hijacking..." -ForegroundColor Yellow
    
    $priorityCmd = "/realtime"
    $affinityCmd = if ($affinityHex -ne "") { "/affinity $affinityHex" } else { "" }
    
    # Set the Debugger command
    $debuggerCmd = "powershell -win 1 -nop -c rnp -path '$ifeoPath' -name 'Debugger' -newname 'NoDebugger' -force; cmd /c start $priorityCmd $affinityCmd `"`" `"\`$args`" "
    Set-ItemProperty -Path $ifeoPath -Name "Debugger" -Value $debuggerCmd
    Set-ItemProperty -Path $ifeoPath -Name "GlobalFlag" -Value 0x200 -Type DWord
    
    # Set the Reset on Exit
    if (!(Test-Path $silentExitPath)) { New-Item -Path $silentExitPath -Force | Out-Null }
    $resetCmd = "powershell -win 1 -nop -c rnp -path '$ifeoPath' -name 'NoDebugger' -newname 'Debugger' -force"
    Set-ItemProperty -Path $silentExitPath -Name "MonitorProcess" -Value $resetCmd
    Set-ItemProperty -Path $silentExitPath -Name "ReportingMode" -Value 1 -Type DWord
} else {
    # STANDARD METHOD for 1, 2, 3
    Set-ItemProperty -Path $perfPath -Name "CpuPriorityClass" -Value $prioVal -Type DWord
    if ($affinityHex -ne "") {
        $mask = [long][Math]::Pow(16, $affinityHex.Replace("0x","").Length) # Re-calc for QWord
        Set-ItemProperty -Path $perfPath -Name "CpuAffinityMask" -Value $mask -Type QWord
    }
    Write-Host "Standard Priority $prioVal applied." -ForegroundColor Green
}

Write-Host "`n[SUCCESS] Settings applied for $exeName." -ForegroundColor Green
pause
