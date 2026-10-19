<#
.SYNOPSIS
    Модуль для удаленного управления компьютерами и серверами в доменной инфраструктуре Active Directory
.DESCRIPTION
    Модуль предоставляет функции для управления компьютерами и серверами в доменной инфраструктуре Active Directory:
    Вызовы публичных функций журналируются вместе с параметрами и результатом выполнения.
    
    Remove-AppOnRemotePC - удаляет приложение на удаленном компьютере
    Find-KB-onRemotePC - ищет установленный KB на удаленном компьютере
    Get-InstalledWindowsUpdate - получает названия пакетов обновлений, подходящих под заданные фильтры
    Install-WindowsUpdateOnRemotePC - копирует локальный MSU-файл на удаленный компьютер и устанавливает его
    Install-WindowsUpdateFromRepositoryOnRemotePC - устанавливает MSU-файл из централизованного хранилища
    Install-MsiOnRemotePC - устанавливает MSI пакет на удаленном компьютере
    Start-WsusAgent - инициирует поиск обновлений через клиент Windows Update на удаленном компьютере
    Get-WinBuild - получает версию сборки Windows на удаленном компьютере
    Copy-ToRemotePC - копирует файл на удаленный компьютер
    Get-LocalAdmin - получает список локальных администраторов на удаленном компьютере
    Get-LocalFile - получает сведения о версии указанного файла на удаленном компьютере
    Start-RemoteProgram - запускает программу на удаленном компьютере
    Get-AppFromRemotePC - получает название и версию указанного приложения на удаленном компьютере
    Disable-ServiceOnRemotePC - отключает службу на удаленном компьютере
    Start-ServiceOnRemotePC - запускает службу на удаленном компьютере
    Enable-ServiceOnRemotePC - включает службу на удаленном компьютере
    Set-ServiceStartupTypeOnRemotePC - изменяет тип запуска службы на удаленном компьютере
    Get-ServiceStartupTypeOnRemotePC - получает тип запуска службы на удаленном компьютере
    Get-ServiceStatusOnRemotePC - получает статус службы на удаленном компьютере
    Find-PCbyUser - ищет компьютер по атрибуту LastLogonUser в Active Directory
    Find-PCbyUserInDescription - ищет компьютер по имени пользователя в поле Description объекта Active Directory

.NOTES
    Совместимость: Windows PowerShell 5.1, PowerShell 7+.
    Автор: Aleksandr Savgirya
    Дата: 2026-10-08

.FUNCTIONS
    Copy-ToRemotePC, Get-LocalAdmin, Get-LocalFile, Start-RemoteProgram, Get-WinBuild, Get-InstalledWindowsUpdate,
    Install-WindowsUpdateOnRemotePC, Install-WindowsUpdateFromRepositoryOnRemotePC, Install-MsiOnRemotePC,
    Find-KB-onRemotePC, Remove-AppOnRemotePC, Get-AppFromRemotePC, Start-WsusAgent, Disable-ServiceOnRemotePC,
    Start-ServiceOnRemotePC, Enable-ServiceOnRemotePC, Set-ServiceStartupTypeOnRemotePC,
    Get-ServiceStartupTypeOnRemotePC, Get-ServiceStatusOnRemotePC, Find-PCbyUser, Find-PCbyUserInDescription
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

function Install-WindowsUpdateFileOnRemotePC {
    param (
        [string]$ComputerName,
        [string]$UpdatePath
    )
    try {
        if ([System.IO.Path]::GetExtension($UpdatePath) -ne '.msu') {
            throw "Ожидается автономный файл обновления с расширением .msu: $UpdatePath"
        }
        if (-not (Test-Path -LiteralPath $UpdatePath -PathType Leaf)) {
            throw "Файл обновления не найден или недоступен: $UpdatePath"
        }

        $updateFileName = '{0}_{1}.msu' -f [guid]::NewGuid().ToString('N'), [System.IO.Path]::GetFileNameWithoutExtension($UpdatePath)
        $remoteSharePath = "\\$ComputerName\C$\Windows\Temp\$updateFileName"
        $remoteLocalPath = "C:\Windows\Temp\$updateFileName"
        Copy-Item -LiteralPath $UpdatePath -Destination $remoteSharePath -Force -ErrorAction Stop

        Invoke-Command -ComputerName $ComputerName -ArgumentList $remoteLocalPath -ScriptBlock {
            param ($LocalUpdatePath)

            try {
                $installer = Start-Process -FilePath 'wusa.exe' `
                    -ArgumentList "/quiet /norestart `"$LocalUpdatePath`"" `
                    -Wait -PassThru -ErrorAction Stop

                if ($installer.ExitCode -notin @(0, 3010, 2359302)) {
                    throw "Windows Update Standalone Installer завершился с кодом $($installer.ExitCode)"
                }
                if ($installer.ExitCode -eq 3010) {
                    Write-Warning 'Обновление установлено; для завершения установки требуется перезагрузка компьютера.'
                }
            }
            finally {
                Remove-Item -LiteralPath $LocalUpdatePath -Force -ErrorAction Stop
            }
        } -ErrorAction Stop

        return $true
    }
    catch {
        Write-Warning "Ошибка при установке обновления на компьютере $ComputerName из файла $UpdatePath : $_"
        return $false
    }
}

function Install-WindowsUpdateOnRemotePC {
    param (
        [string]$ComputerName,
        [string]$UpdatePath
    )
    Install-WindowsUpdateFileOnRemotePC -ComputerName $ComputerName -UpdatePath $UpdatePath
}

function Install-WindowsUpdateFromRepositoryOnRemotePC {
    param (
        [string]$ComputerName,
        [string]$RepositoryPath
    )
    Install-WindowsUpdateFileOnRemotePC -ComputerName $ComputerName -UpdatePath $RepositoryPath
}

function Start-WsusAgent {
    param (
        [string]$ComputerName
    )
    try {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Start-Service -Name 'wuauserv' -ErrorAction Stop

            $usoClientPath = Join-Path $env:SystemRoot 'System32\UsoClient.exe'
            if (Test-Path -LiteralPath $usoClientPath) {
                Start-Process -FilePath $usoClientPath -ArgumentList 'StartScan' -ErrorAction Stop
            }
            else {
                Start-Process -FilePath 'wuauclt.exe' -ArgumentList '/detectnow' -ErrorAction Stop
                Start-Process -FilePath 'wuauclt.exe' -ArgumentList '/reportnow' -ErrorAction Stop
            }
        } -ErrorAction Stop
        return $true
    }
    catch {
        Write-Warning "Ошибка при запуске поиска обновлений WSUS на компьютере $ComputerName : $_"
        return $false
    }
}

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
            # Удаляем указанный пакет на удаленном компьютере
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

function Find-PCbyUserInDescription {
    param (
        [string]$Username
    )
    try {
        $descriptionFilter = "*$Username*"
        $computer = Get-ADComputer -Filter { Description -like $descriptionFilter } -Properties Description |
            Select-Object -ExpandProperty Name
        return $computer
    }
    catch {
        Write-Warning "Ошибка при поиске компьютера для пользователя $Username : $_"
        return $false
    }
}

$script:RemoteMgmtLogLock = New-Object object

function Write-RemoteMgmtLog {
    param (
        [string]$OperationId,
        [string]$FunctionName,
        [string]$ComputerName,
        [string]$Target,
        [System.Collections.IDictionary]$Parameters,
        [ValidateSet('Started', 'Succeeded', 'Failed')]
        [string]$Status,
        [string]$Message
    )

    try {
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

        $logPath = [System.IO.Path]::GetFullPath($logPath)
        $logDirectory = [System.IO.Path]::GetDirectoryName($logPath)
        if ([string]::IsNullOrWhiteSpace($logDirectory)) {
            $logDirectory = [Environment]::CurrentDirectory
        }
        [System.IO.Directory]::CreateDirectory($logDirectory) | Out-Null

        $entry = [ordered]@{
            TimestampUtc = [DateTime]::UtcNow.ToString('o')
            OperationId  = $OperationId
            Function     = $FunctionName
            ComputerName = $ComputerName
            Target       = $Target
            Parameters   = $Parameters
            Status       = $Status
            Message      = $Message
        }
        $line = ($entry | ConvertTo-Json -Compress) + [Environment]::NewLine

        [System.Threading.Monitor]::Enter($script:RemoteMgmtLogLock)
        try {
            [System.IO.File]::AppendAllText(
                $logPath,
                $line,
                ([System.Text.UTF8Encoding]::new($false))
            )
        }
        finally {
            [System.Threading.Monitor]::Exit($script:RemoteMgmtLogLock)
        }
    }
    catch {
        Write-Warning "Не удалось записать журнал remote-mgmt: $_"
    }
}

$publicFunctions = @(
    'Copy-ToRemotePC'
    'Get-LocalAdmin'
    'Get-LocalFile'
    'Start-RemoteProgram'
    'Get-WinBuild'
    'Get-InstalledWindowsUpdate'
    'Install-WindowsUpdateOnRemotePC'
    'Install-WindowsUpdateFromRepositoryOnRemotePC'
    'Start-WsusAgent'
    'Install-MsiOnRemotePC'
    'Find-KB-onRemotePC'
    'Remove-AppOnRemotePC'
    'Get-AppFromRemotePC'
    'Disable-ServiceOnRemotePC'
    'Start-ServiceOnRemotePC'
    'Enable-ServiceOnRemotePC'
    'Set-ServiceStartupTypeOnRemotePC'
    'Get-ServiceStartupTypeOnRemotePC'
    'Get-ServiceStatusOnRemotePC'
    'Find-PCbyUser'
    'Find-PCbyUserInDescription'
)

$script:RemoteMgmtImplementations = @{}
foreach ($functionName in $publicFunctions) {
    $implementation = (Get-Command -Name $functionName -CommandType Function -ErrorAction Stop).ScriptBlock
    $script:RemoteMgmtImplementations[$functionName] = $implementation
    $parameterBlock = $implementation.Ast.ParamBlock.Extent.Text
    $wrapperDefinition = @"
function $functionName {
    $parameterBlock
    `$operationId = [guid]::NewGuid().ToString()
    `$target = if (`$ComputerName) { `$ComputerName } elseif (`$Username) { `$Username } else { '' }
    `$loggedParameters = [ordered]@{}
    foreach (`$parameterName in `$PSBoundParameters.Keys) {
        if (`$parameterName -match '(?i)password|secret|credential|token|argument|args') {
            `$loggedParameters[`$parameterName] = '[REDACTED]'
        }
        else {
            `$loggedParameters[`$parameterName] = `$PSBoundParameters[`$parameterName]
        }
    }
    Write-RemoteMgmtLog -OperationId `$operationId -FunctionName '$functionName' -ComputerName `$ComputerName -Target `$target -Parameters `$loggedParameters -Status 'Started' -Message 'Operation started.'

    try {
        `$result = & (`$script:RemoteMgmtImplementations['$functionName']) @PSBoundParameters
        if (`$result -is [bool] -and -not `$result) {
            Write-RemoteMgmtLog -OperationId `$operationId -FunctionName '$functionName' -ComputerName `$ComputerName -Target `$target -Parameters `$loggedParameters -Status 'Failed' -Message 'Operation returned false; check the warning output for details.'
        }
        else {
            Write-RemoteMgmtLog -OperationId `$operationId -FunctionName '$functionName' -ComputerName `$ComputerName -Target `$target -Parameters `$loggedParameters -Status 'Succeeded' -Message 'Operation completed.'
        }
        return `$result
    }
    catch {
        Write-RemoteMgmtLog -OperationId `$operationId -FunctionName '$functionName' -ComputerName `$ComputerName -Target `$target -Parameters `$loggedParameters -Status 'Failed' -Message `$_.Exception.Message
        throw
    }
}
"@
    Invoke-Expression $wrapperDefinition
}

Export-ModuleMember -Function Copy-ToRemotePC, Get-LocalAdmin, Get-LocalFile, Start-RemoteProgram, Get-WinBuild, Get-InstalledWindowsUpdate, Install-WindowsUpdateOnRemotePC, Install-WindowsUpdateFromRepositoryOnRemotePC, Start-WsusAgent, Install-MsiOnRemotePC, Find-KB-onRemotePC, Remove-AppOnRemotePC, Get-AppFromRemotePC, Disable-ServiceOnRemotePC, Start-ServiceOnRemotePC, Enable-ServiceOnRemotePC, Set-ServiceStartupTypeOnRemotePC, Get-ServiceStartupTypeOnRemotePC, Get-ServiceStatusOnRemotePC, Find-PCbyUser, Find-PCbyUserInDescription