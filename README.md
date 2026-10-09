# remote-mgmt

## Описание проекта

`remote-mgmt` — это модуль PowerShell для удалённого управления компьютерами и серверами в доменной инфраструктуре Active Directory. Он предназначен для системных администраторов, которым необходимо быстро и безопасно выполнять типовые операции на удалённых рабочих станциях и серверах без необходимости заходить на каждую машину вручную.

Модуль позволяет получать информацию о состоянии системы, управлять установленными программами, службами, обновлениями и файлами, а также выполнять массовые административные действия в сети Windows.

## Основные возможности

- удалённая установка и удаление приложений;
- поиск и просмотр установленных обновлений и патчей KB;
- запуск и управление службами на удалённых машинах;
- получение сведений о версии Windows и сборке ОС;
- копирование файлов на удалённый компьютер;
- просмотр локальных администраторов и файлов;
- запуск программ на удалённой машине;
- поиск компьютера по имени пользователя в домене;
- работа с WSUS-агентом и служебными задачами обновлений.

## Ключевые функции модуля

- `Remove-AppOnRemotePC`
- `Find-KB-onRemotePC`
- `Get-InstalledWindowsUpdate`
- `Install-MsiOnRemotePC`
- `Start-WsusAgentUpdate`
- `Get-WinBuild`
- `Copy-ToRemotePC`
- `Get-LocalAdmin`
- `Get-LocalFile`
- `Start-RemoteProgram`
- `Get-AppFromRemotePC`
- `Disable-ServiceOnRemotePC`
- `Start-ServiceOnRemotePC`
- `Enable-ServiceOnRemotePC`
- `Set-ServiceStartupTypeOnRemotePC`
- `Get-ServiceStartupTypeOnRemotePC`
- `Get-ServiceStatusOnRemotePC`
- `Find-PCbyUser`

## Требования

- Windows PowerShell 5.1 или PowerShell 7+
- доступ к управляемым компьютерам в домене;
- включённый удалённый доступ к узлам (`WinRM` / PowerShell Remoting);
- права администратора или необходимые разрешения на целевых машинах.

## Пример использования

```powershell
Import-Module ./remotemgmt.psm1

Get-WinBuild -ComputerName PC01
Get-LocalAdmin -ComputerName PC01
Copy-ToRemotePC -ComputerName PC01 -SourcePath "C:\Temp\setup.msi" -RemotePath "C$\Temp"
Start-ServiceOnRemotePC -ComputerName PC01 -ServiceName "wuauserv"
Find-PCbyUser -UserName "ivanov"
```

## Назначение проекта

Проект создан для автоматизации административных операций в среде Windows с большим количеством компьютеров и серверов. Он помогает сократить время на рутинную поддержку инфраструктуры, снизить вероятность ошибок при ручном выполнении команд и стандартизировать процессы удалённого администрирования.
