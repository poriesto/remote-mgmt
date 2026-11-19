<# Force Wsus Client Scan Updates 
.SYNOPSIS:
    Forces the Windows Update Agent on a remote computer to scan for updates and report its status to the WSUS server.
.DESCRIPTION:
    This script is designed to trigger the Windows Update Agent on a remote computer to perform a scan
.NOTES:
    - The script requires administrative privileges on the remote computer.
    - Requires PowerShell remoting to be enabled on the remote computer.
    - Requires installed Active Directory module for PowerShell.
    - Compatibility: Windows PowerShell 5.1, PowerShell 7+.
#>

[CmdletBinding()]
param (
    [string]$LogPath
)

import-Module ActiveDirectory
import-Module remotemgmt

$script:WsusOperationId = [Guid]::NewGuid().ToString()
$script:WsusLogLock = New-Object object
$script:WsusSuccessCount = 0
$script:WsusFailureCount = 0

if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    $env:REMOTEMGMT_LOG_PATH = $LogPath
}

function Get-WsusLogPath {
    $logPath = $env:REMOTEMGMT_LOG_PATH
    if ([string]::IsNullOrWhiteSpace($logPath)) {
        $logRoot = $env:ProgramData
        if ([string]::IsNullOrWhiteSpace($logRoot)) {
            $logRoot = [Environment]::GetFolderPath('LocalApplicationData')
        }
        if ([string]::IsNullOrWhiteSpace($logRoot)) {
            $logRoot = $HOME
        }
        $logPath = Join-Path (Join-Path $logRoot 'RemoteMgmt') 'remote-mgmt.jsonl'
    }
    return [System.IO.Path]::GetFullPath($logPath)
}

function Write-WsusResultLog {
    param (
        [string]$ComputerName,
        [ValidateSet('Started', 'Succeeded', 'Failed')]
        [string]$Status,
        [string]$Message
    )

    try {
        $logPath = Get-WsusLogPath
        $logDirectory = [System.IO.Path]::GetDirectoryName($logPath)
        if (-not [string]::IsNullOrWhiteSpace($logDirectory)) {
            [System.IO.Directory]::CreateDirectory($logDirectory) | Out-Null
        }

        $entry = [ordered]@{
            TimestampUtc = [DateTime]::UtcNow.ToString('o')
            OperationId  = $script:WsusOperationId
            Function     = 'ForceWsusClientScanUpdates'
            ComputerName = $ComputerName
            Target       = $ComputerName
            Parameters   = @{}
            Status       = $Status
            Message      = $Message
        }
        $line = ($entry | ConvertTo-Json -Compress) + [Environment]::NewLine

        [System.Threading.Monitor]::Enter($script:WsusLogLock)
        try {
            [System.IO.File]::AppendAllText(
                $logPath,
                $line,
                ([System.Text.UTF8Encoding]::new($false))
            )
        }
        finally {
            [System.Threading.Monitor]::Exit($script:WsusLogLock)
        }
    }
    catch {
        Write-Warning "Не удалось записать журнал запуска проверки обновлений WSUS: $_"
    }
}

function Process-WsusComputer {
    param (
        [string]$ComputerName
    )

    Write-Host "Компьютер: $ComputerName" -ForegroundColor Green
    Write-WsusResultLog -ComputerName $ComputerName -Status Started -Message 'Начата обработка компьютера.'

    try {
        $connectionResult = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet
    }
    catch {
        $connectionResult = $false
    }

    if (-not $connectionResult) {
        $message = "Не удалось подключиться к $ComputerName."
        Write-Host $message -ForegroundColor Red
        Write-WsusResultLog -ComputerName $ComputerName -Status Failed -Message $message
        $script:WsusFailureCount++
        return $false
    }

    Write-Host "Подключение к $ComputerName успешно." -ForegroundColor Green
    $success = Start-WsusAgent -ComputerName $ComputerName
    if ($success -eq $true) {
        $message = "Поиск обновлений WSUS запущен на $ComputerName."
        Write-Host $message -ForegroundColor Green
        Write-WsusResultLog -ComputerName $ComputerName -Status Succeeded -Message $message
        $script:WsusSuccessCount++
        return $true
    }

    $message = "Не удалось запустить поиск обновлений WSUS на $ComputerName."
    Write-Host $message -ForegroundColor Red
    Write-WsusResultLog -ComputerName $ComputerName -Status Failed -Message $message
    $script:WsusFailureCount++
    return $false
}

Write-Host "Журнал результатов: $(Get-WsusLogPath)" -ForegroundColor Yellow
Write-Host "Force Wsus Client Scan Updates" -ForegroundColor Green
Write-Host "Выберите метод заполнения списка компьютеров для обработки:" -ForegroundColor Yellow
Write-Host "1. Ввести список компьютеров из файла" -ForegroundColor Cyan
Write-Host "2. Получить список компьютеров из Active Directory по определенной группе" -ForegroundColor Cyan
Write-Host "3. Получить полный список компьютеров из Active Directory" -ForegroundColor Cyan
$choice = Read-Host "Введите номер метода (1-3):"   

switch ($choice) {
    1{
        Write-Host "Вы выбрали метод 1: Ввести список компьютеров из файла." -ForegroundColor Green
        $filePath = Read-Host "Введите путь к файлу с именами компьютеров" 
        $pcList = Get-Content -Path $filePath
        $pcList = $pcList | Where-Object { $_ -ne "" }  # Убираем пустые строки
        $pcList = $pcList | ForEach-Object { $_.Trim() }  # Убираем пробелы в начале и конце строк
        $pcList = $pcList | Sort-Object -Unique  # Убираем дубликаты
        $pcList | ForEach-Object { Process-WsusComputer -ComputerName $_ }
    }
    2{
        Write-Host "Вы выбрали метод 2: Получить список компьютеров из Active Directory по определенной группе." -ForegroundColor Green
        $groupName = Read-Host "Введите имя группы в Active Directory"
        $pcList = Get-ADComputer -Filter {OperatingSystem -like "*Windows*"} -SearchBase "CN=$groupName,OU=Groups,DC=yourdomain,DC=com" | Select-Object -ExpandProperty Name
        $pcList | ForEach-Object { Process-WsusComputer -ComputerName $_ }
    }
    3{
        Write-Host "Вы выбрали метод 3: Получить полный список компьютеров из Active Directory." -ForegroundColor Green
        $pcList = Get-ADComputer -Filter {OperatingSystem -like "*Windows*"} | Select-Object -ExpandProperty Name
        $pcList | ForEach-Object { Process-WsusComputer -ComputerName $_ }
    }
    Default {}
}

$summary = "Итого: успешно $($script:WsusSuccessCount), ошибок $($script:WsusFailureCount)."
Write-Host $summary -ForegroundColor Yellow
Write-WsusResultLog -ComputerName '' -Status $(if ($script:WsusFailureCount -gt 0) { 'Failed' } else { 'Succeeded' }) -Message $summary