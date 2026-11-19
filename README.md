# remote-mgmt

## Описание проекта

`remote-mgmt` — это модуль PowerShell для удалённого управления компьютерами и серверами в доменной инфраструктуре Active Directory. Он предназначен для системных администраторов, которым необходимо выполнять типовые операции на удалённых рабочих станциях и серверах без необходимости заходить на каждую машину вручную.

Модуль позволяет получать сведения о системе, управлять установленными программами и службами, запускать поиск обновлений через WSUS и работать с файлами на отдельных удалённых компьютерах.

## Основные возможности

- удалённая установка и удаление приложений;
- установка MSI-пакетов на удалённый компьютер;
- установка автономных MSU-обновлений с локального компьютера или из централизованного хранилища;
- просмотр подходящих под заданные фильтры пакетов обновлений и поиск установленного патча KB;
- запуск и управление службами на удалённых машинах;
- получение сведений о версии Windows и сборке ОС;
- копирование файлов на удалённый компьютер;
- просмотр локальных администраторов и сведений о версии указанного файла;
- запуск программ на удалённой машине;
- поиск компьютера по имени пользователя через атрибут `LastLogonUser` или поле `Description` объекта компьютера;
- инициирование поиска обновлений через клиент Windows Update на удалённом компьютере.
- настройка WinRM и удалённого реестра;
- включение и отключение брандмауэра Windows на удалённых компьютерах.

## Ключевые функции модуля

- `Remove-AppOnRemotePC`
- `Find-KB-onRemotePC`
- `Get-InstalledWindowsUpdate`
- `Install-WindowsUpdateOnRemotePC`
- `Install-WindowsUpdateFromRepositoryOnRemotePC`
- `Install-MsiOnRemotePC`
- `Start-WsusAgent`
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
- `Find-PCbyUserInDescription`
- `Repair-Winrm`
- `Disable-WindowsFirewallOnRemotePC`
- `Enable-WindowsFirewallOnRemotePC`
- `Enable-RemoteRegistryOnRemotePC`
- `Disable-RemoteRegistryOnRemotePC`

## Требования

- Windows PowerShell 5.1 или PowerShell 7+
- доступ к управляемым компьютерам в домене;
- включённый удалённый доступ к узлам (`WinRM` / PowerShell Remoting);
- права администратора или необходимые разрешения на целевых машинах;
- модуль Active Directory, если используются функции поиска компьютеров или сценарий пакетного запуска проверки WSUS;
- административные права на целевых компьютерах для операций настройки системы и управления службами.

Модуль и вспомогательный сценарий рассчитаны на выполнение с Windows-компьютера в доменной среде. Для функций поиска в Active Directory предварительно импортируйте модуль:

```powershell
Import-Module ActiveDirectory
```

## Пример использования

```powershell
Import-Module ./remotemgmt.psm1

Get-WinBuild -ComputerName PC01
Get-LocalAdmin -ComputerName PC01
Copy-ToRemotePC -ComputerName PC01 -SourcePath "C:\Temp\setup.msi" -RemotePath "C$\Temp"
Start-ServiceOnRemotePC -ComputerName PC01 -ServiceName "wuauserv"
Start-WsusAgent -ComputerName PC01
Install-WindowsUpdateOnRemotePC -ComputerName PC01 -UpdatePath "C:\Updates\windows-update.msu"
Install-WindowsUpdateFromRepositoryOnRemotePC -ComputerName PC01 -RepositoryPath "\\fileserver\Updates\windows-update.msu"
Find-PCbyUser -Username "ivanov" # ищет по атрибуту LastLogonUser
Find-PCbyUserInDescription -Username "ivanov" # ищет "ivanov" в поле Description компьютера в Active Directory
Install-MsiOnRemotePC -ComputerName PC01 -MsiPath "C:\Packages\app.msi" -MsiArgs "/quiet"
Repair-Winrm -ComputerName PC01
Disable-WindowsFirewallOnRemotePC -ComputerName PC01
Enable-WindowsFirewallOnRemotePC -ComputerName PC01
Enable-RemoteRegistryOnRemotePC -ComputerName PC01
Disable-RemoteRegistryOnRemotePC -ComputerName PC01
```

Для обеих функций используется файл формата `.msu`. Файл копируется в `C:\Windows\Temp` целевого компьютера, устанавливается через `wusa.exe` в тихом режиме, после чего временная копия удаляется. При установке из хранилища путь к файлу должен быть доступен компьютеру, с которого запускается команда. Нужны права на запись в административную шару `C$` целевой машины и доступ к ней по сети.

## Пакетный запуск проверки WSUS

В репозитории есть интерактивный сценарий `ForceWsusClientScanUpdates.ps1`. Он запускает поиск обновлений через модуль `remotemgmt` для списка компьютеров из файла, выбранной группы Active Directory или всего домена.

```powershell
Import-Module ActiveDirectory
.\ForceWsusClientScanUpdates.ps1
```

Можно заранее задать файл журнала:

```powershell
.\ForceWsusClientScanUpdates.ps1 -LogPath "C:\Logs\remote-mgmt.jsonl"
```

Сценарий выводит итоговое число успешно обработанных компьютеров и ошибок. Для выбора группы в пункте меню 2 должна быть настроена корректная SearchBase для домена и OU с группами.

## Журнал операций

Все публичные функции модуля записывают JSON Lines-журнал: начало операции и её итог (`Succeeded` или `Failed`), UTC-время, имя функции, целевой компьютер, параметры вызова и идентификатор операции. Аргументы, которые могут содержать секреты (например `ArgumentList` или `MsiArgs`), в журнале заменяются на `[REDACTED]`. Неудачные вызовы, в том числе недоступные компьютеры, можно выбрать для последующей обработки:

```powershell
Get-Content "$env:ProgramData\RemoteMgmt\remote-mgmt.jsonl" |
    ForEach-Object { ConvertFrom-Json $_ } |
    Where-Object Status -eq 'Failed' |
    Select-Object TimestampUtc, ComputerName, Function, OperationId, Message
```

По умолчанию журнал хранится в `%ProgramData%\RemoteMgmt\remote-mgmt.jsonl`. Чтобы указать другой путь, задайте переменную окружения `REMOTEMGMT_LOG_PATH` до запуска команд модуля. При ошибке записи журналирования функция выдаёт предупреждение; сама операция при этом продолжается.

## Назначение проекта

Проект создан для автоматизации административных операций в среде Windows с большим количеством компьютеров и серверов. Он помогает сократить время на рутинную поддержку инфраструктуры, снизить вероятность ошибок при ручном выполнении команд и стандартизировать процессы удалённого администрирования.
