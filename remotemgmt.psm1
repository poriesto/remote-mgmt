<#
.SYNOPSIS
    Модуль управление компьютерами и серверами в доменной инфраструктуре Active Directory
.DESCRIPTION
    Модуль предоставляет функции для управления компьютерами и серверами в доменной инфраструктуре Active Directory:
    
    Remove-AppOnRemotePC - удаляет приложение на удаленном компьютере
    Find-KB-onRemotePC - ищет установленный KB на удаленном компьютере
    Get-InstalledWindowsUpdate - получает список установленных обновлений на удаленном компьютере
    Install-MsiOnRemotePC - устанавливает MSI пакет на удаленном компьютере
    Start-WsusAgentUpdate - запускает обновление WSUS агента на удаленном компьютере
    Get-WinBuild - получает версию сборки Windows на удаленном компьютере
    Copy-ToRemotePC - копирует файл на удаленный компьютер
    Get-LocalAdmin - получает список локальных администраторов на удаленном компьютере
    Get-LocalFile - получает список локальных файлов на удаленном компьютере
    Start-RemoteProgram - запускает программу на удаленном компьютере
    Get-AppFromRemotePC - получает список установленных приложений на удаленном компьютере
    Disable-ServiceOnRemotePC - отключает службу на удаленном компьютере
    Start-ServiceOnRemotePC - запускает службу на удаленном компьютере
    Enable-ServiceOnRemotePC - включает службу на удаленном компьютере
    Set-ServiceStartupTypeOnRemotePC - изменяет тип запуска службы на удаленном компьютере
    Get-ServiceStartupTypeOnRemotePC - получает тип запуска службы на удаленном компьютере
    Get-ServiceStatusOnRemotePC - получает статус службы на удаленном компьютере
    Find-PCbyUser - ищет компьютер по имени пользователя в доменной инфраструктуре Active Directory

.NOTES
    Совместимость: Windows PowerShell 5.1, PowerShell 7+.
    Автор: Aleksandr Savgirya
    Дата: 2026-10-08

.FUNCTIONS
    Remove-AppOnRemotePC, Find-KB-onRemotePC,Get-InstalledWindowsUpdate,Install-MsiOnRemotePC,Start-WsusAgentUpdate,
    Get-WinBuild,Copy-ToRemotePC,Get-LocalAdmin,Get-LocalFile,Start-RemoteProgram,Disable-ServiceOnRemotePC,Start-ServiceOnRemotePC,Enable-ServiceOnRemotePC,Set-ServiceStartupTypeOnRemotePC,Get-ServiceStartupTypeOnRemotePC,Get-ServiceStatusOnRemotePC,Find-PCbyUser
#>

function Copy-ToRemotePC {
    param (
        [string]$ComputerName,
        [string]$SourcePath,
        [string]$RemotePath
    )
    try {
        $dest = "\\"+$ComputerName+"\"+$RemotePath
        Copy-Item -Path $SourcePath -Destination $dest
    }
    catch {
        Write-Warning "Ошибка при обработке АРМ  $ComputerName :  $_ "
        return $false
    }
}

function Get-LocalAdmin{
    param(
        [string] $ComputerName
    )
    try{
        # Проверяем доступность компьютера
        if (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet) 
        {
            # Выполнение действия на удаленном АРМ
            $response = Invoke-Command -ComputerName $ComputerName -ScriptBlock{
                Get-LocalGroupMember -Group 'Administrators'
            } -ErrorAction Stop
            return $response
        } 
        else 
        {
            Write-Warning "Компьютер $ComputerName недоступен"
            return $false
        }

    }
    catch{
        Write-Warning "Ошибка при обработке компьютера $ComputerName : $_"
        return $false
    }
} 

function Get-LocalFile{
    param(
        [string] $ComputerName,
        [string] $file
    )
    try{
        $fileinfo = Invoke-Command -ComputerName $ComputerName -ScriptBlock{
            (Get-Item $using:file ).VersionInfo
        }
        return $fileinfo
    }
    catch{
        Write-Warning "Ошибка при обработке компьютера $ComputerName : $_"
        return $false
    }
}

function Start-RemoteProgram
{
    param(
        [string] $ComputerName,
        [string] $AppPath,
        [string] $ArgumentList
    )
    try {
        Write-Host "Выполняется запуск программы $AppPath с параметрами\n$ArgumentList\nПК - $ComputerName"
        $response = Invoke-Command -ComputerName $ComputerName -ScriptBlock{
            Start-Process -FilePath $using:AppPath -ArgumentList $using:ArgumentList
        }
        return $response
    }
    catch {
        Write-Warning "Ошибка при запуске приложения $AppPath с параметрами\n$ArgumentList"
        return $false
    }
}

function Get-WinBuild
{
    param(
        [string] $ComputerName
    )
    try {
        $response = Invoke-Command -ComputerName $ComputerName -ScriptBlock{
            Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" | Select-Object ProductName,DisplayVersion,UBR
        }
        return $response
    }
    catch {
        Write-Warning "Ошибка при обработке компьютера $ComputerName : $_"
        return $false
    }
}

function Get-InstalledWindowsUpdate
{
    param(
        [string] $ComputerName
    )
    try {
        $updates = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Get-Package |
                Where-Object {
                    $_.Name -like "*Cumulative Update*" -or
                    $_.Name -like "*накопительное обновление*" -or
                    $_.Name -like "*NET*"
                } |
                Select-Object Name
        }
        return $updates
    }
    catch {
        Write-Warning "Ошибка при обработке компьютера $ComputerName : $_"
        return $false
    }
}
#Функция удаленной установки MSI пакета на АРМ или сервер
function Install-MsiOnRemotePC
{
    param(
        [string]$ComputerName,
        [string]$MsiPath,
        [string]$MsiArgs
    )
    try{
        if(Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)
        {
            $InstallString = "/i" + $MsiPath + $MsiArgs
            Invoke-Command -ComputerName $ComputerName -ScriptBlock{
                Start-Process msiexec.exe -ArgumentList $InstallString
            } -ErrorAction Stop
            return $true
        }
        else
        {
            return $false
        }
    }
    catch{
        return $false
    }
}

function Find-KB-onRemotePC
{
param(
    [string] $ComputerName,
    [string] $kb
)
    try{
        $kbinfo = Invoke-Command -ComputerName $ComputerName -ScriptBlock{
            Get-HotFix -id $using:kb | Select-Object HotFixID,InstalledOn 
        }
        return $kbinfo
    }
    catch{
        Write-Warning "Ошибка при обработке компьютера $ComputerName : $_"
        return $false
    }
}

function Remove-AppOnRemotePC 
{
    param (
        [string]$ComputerName,
        [string]$App
    )
    try 
    {
        # Проверяем доступность компьютера
        if (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet) 
        {
            # Отключаем гибернацию через удаленное выполнение команды
            Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                Get-Package -Name $Using:App | Uninstall-Package
            } -ErrorAction Stop
            return $true
        } else 
        {
            Write-Warning "Компьютер $ComputerName недоступен"
            return $false
        }
    } 
    catch 
    {
        Write-Warning "Ошибка при обработке компьютера $ComputerName : $_"
        return $false
    }
}
function Get-AppFromRemotePC
{
param (
        [string]$ComputerName,
        [string]$App
    )
    try 
    {
        # Проверяем доступность компьютера
        if (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet) 
        {
            # Выполнение действия на удаленном АРМ
            $appInfo = Invoke-Command -ComputerName $ComputerName -ScriptBlock{
                Get-Package -Name $Using:App | Select-Object Name,Version
            } -ErrorAction Stop
            return $appInfo
        } 
        else 
        {
            Write-Warning "Компьютер $ComputerName недоступен"
            return $false
        }
    } catch 
    {
        Write-Warning "Ошибка при обработке компьютера $ComputerName : $_"
        return $false
    }
}

function Get-ServiceStartupTypeOnRemotePC {
    param (
        [string]$ComputerName,
        [string]$ServiceName
    )
    try {
        $startupType = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            (Get-Service -Name $using:ServiceName).StartupType
        } -ErrorAction Stop
        return $startupType
    }
    catch {
        Write-Warning "Ошибка при обработке компьютера $ComputerName : $_"
        return $false
    }
}

function Get-ServiceStatusOnRemotePC {
    param (
        [string]$ComputerName,
        [string]$ServiceName
    )
    try {
        $status = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            (Get-Service -Name $using:ServiceName).Status
        } -ErrorAction Stop
        return $status
    }
    catch {
        Write-Warning "Ошибка при обработке компьютера $ComputerName : $_"
        return $false
    }
}

function Disable-ServiceOnRemotePC {
    param (
        [string]$ComputerName,
        [string]$ServiceName
    )
    try {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Stop-Service -Name $using:ServiceName -Force
            Set-Service -Name $using:ServiceName -StartupType Disabled
        } -ErrorAction Stop
        return $true
    }
    catch {
        Write-Warning "Ошибка при обработке компьютера $ComputerName : $_"
        return $false
    }
}

function Start-ServiceOnRemotePC {
    param (
        [string]$ComputerName,
        [string]$ServiceName
    )
    try {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Start-Service -Name $using:ServiceName
        } -ErrorAction Stop
        return $true
    }
    catch {
        Write-Warning "Ошибка при обработке компьютера $ComputerName : $_"
        return $false
    }
}

function Enable-ServiceOnRemotePC {
    param (
        [string]$ComputerName,
        [string]$ServiceName,
        [string]$StartupType = "Automatic"  # Значение по умолчанию - Automatic
    )
    try {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Set-Service -Name $using:ServiceName -StartupType $using:StartupType
            Start-Service -Name $using:ServiceName
        } -ErrorAction Stop
        return $true
    }
    catch {
        Write-Warning "Ошибка при обработке компьютера $ComputerName : $_"
        return $false
    }
}

function Set-ServiceStartupTypeOnRemotePC {
    param (
        [string]$ComputerName,
        [string]$ServiceName,
        [string]$StartupType
    )
    try {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Set-Service -Name $using:ServiceName -StartupType $using:StartupType
        } -ErrorAction Stop
        return $true
    }
    catch {
        Write-Warning "Ошибка при обработке компьютера $ComputerName : $_"
        return $false
    }
}

function Find-PCbyUser {
    param (
        [string]$Username
    )
    try {
        $computer = Get-ADComputer -Filter {LastLogonUser -eq $Username} -Properties LastLogonUser | Select-Object -ExpandProperty Name
        return $computer
    }
    catch {
        Write-Warning "Ошибка при поиске компьютера для пользователя $Username : $_"
        return $false
    }
}

Export-ModuleMember -Function Copy-ToRemotePC, Get-LocalAdmin, Get-LocalFile, Start-RemoteProgram, Get-WinBuild, Get-InstalledWindowsUpdate, Install-MsiOnRemotePC, Find-KB-onRemotePC, Remove-AppOnRemotePC, Get-AppFromRemotePC, Disable-ServiceOnRemotePC, Start-ServiceOnRemotePC, Enable-ServiceOnRemotePC, Set-ServiceStartupTypeOnRemotePC, Get-ServiceStartupTypeOnRemotePC, Get-ServiceStatusOnRemotePC, Find-PCbyUser