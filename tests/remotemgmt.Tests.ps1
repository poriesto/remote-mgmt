#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../remotemgmt.psm1'
    Import-Module -Name $modulePath -Force
}

Describe 'remotemgmt module exports' {
    It 'exports all documented public management functions' {
        $expectedFunctions = @(
            'Copy-ToRemotePC'
            'Get-LocalAdmin'
            'Get-LocalFile'
            'Start-RemoteProgram'
            'Get-WinBuild'
            'Get-InstalledWindowsUpdate'
            'Install-MsiOnRemotePC'
            'Find-KB-onRemotePC'
            'Remove-AppOnRemotePC'
            'Get-AppFromRemotePC'
        )

        $actualFunctions = (Get-Command -Module remotemgmt -CommandType Function).Name
        $actualFunctions | Should -HaveCount $expectedFunctions.Count
        foreach ($functionName in $expectedFunctions) {
            $actualFunctions | Should -Contain $functionName
        }
    }
}

Describe 'Copy-ToRemotePC' {
    It 'copies the source file to the computer share' {
        Mock -ModuleName remotemgmt Copy-Item {}

        $result = Copy-ToRemotePC -ComputerName 'pc01' -SourcePath 'C:\build\app.msi' -RemotePath 'C$\Temp\app.msi'

        $result | Should -BeNullOrEmpty
        Should -Invoke -CommandName Copy-Item -ModuleName remotemgmt -Times 1 -Exactly -ParameterFilter {
            $Path -eq 'C:\build\app.msi' -and
            $Destination -eq '\\pc01\C$\Temp\app.msi'
        }
    }

    It 'returns false when copying fails' {
        Mock -ModuleName remotemgmt Copy-Item { throw 'copy failed' }

        $result = Copy-ToRemotePC -ComputerName 'pc01' -SourcePath 'C:\missing.msi' -RemotePath 'C$\Temp\missing.msi'

        $result | Should -Be $false
    }
}

Describe 'Get-LocalAdmin' {
    It 'returns remote local administrators when the computer is reachable' {
        Mock -ModuleName remotemgmt Test-Connection { $true }
        Mock -ModuleName remotemgmt Invoke-Command { [pscustomobject]@{ Name = 'Administrators' } }

        $result = Get-LocalAdmin -ComputerName 'pc01'

        $result.Name | Should -Be 'Administrators'
        Should -Invoke -CommandName Invoke-Command -ModuleName remotemgmt -Times 1 -Exactly -ParameterFilter { $ComputerName -eq 'pc01' }
    }

    It 'returns false and does not invoke remotely when the computer is unreachable' {
        Mock -ModuleName remotemgmt Test-Connection { $false }
        Mock -ModuleName remotemgmt Invoke-Command {}

        $result = Get-LocalAdmin -ComputerName 'pc01'

        $result | Should -Be $false
        Should -Invoke -CommandName Invoke-Command -ModuleName remotemgmt -Times 0 -Exactly
    }

    It 'returns false when the remote command fails' {
        Mock -ModuleName remotemgmt Test-Connection { $true }
        Mock -ModuleName remotemgmt Invoke-Command { throw 'remote failure' }

        $result = Get-LocalAdmin -ComputerName 'pc01'

        $result | Should -Be $false
    }
}

Describe 'Get-LocalFile' {
    It 'returns file version information from the remote computer' {
        Mock -ModuleName remotemgmt Invoke-Command { [pscustomobject]@{ FileVersion = '1.2.3' } }

        $result = Get-LocalFile -ComputerName 'pc01' -File 'C:\app\app.exe'

        $result.FileVersion | Should -Be '1.2.3'
        Should -Invoke -CommandName Invoke-Command -ModuleName remotemgmt -Times 1 -Exactly -ParameterFilter { $ComputerName -eq 'pc01' }
    }

    It 'returns false when the remote file lookup fails' {
        Mock -ModuleName remotemgmt Invoke-Command { throw 'file not found' }

        $result = Get-LocalFile -ComputerName 'pc01' -File 'C:\missing.exe'

        $result | Should -Be $false
    }
}

Describe 'Start-RemoteProgram' {
    It 'returns the remote process result' {
        Mock -ModuleName remotemgmt Invoke-Command { 'started' }

        $result = Start-RemoteProgram -ComputerName 'pc01' -AppPath 'C:\app\app.exe' -ArgumentList '/quiet'

        $result | Should -Be 'started'
        Should -Invoke -CommandName Invoke-Command -ModuleName remotemgmt -Times 1 -Exactly -ParameterFilter { $ComputerName -eq 'pc01' }
    }

    It 'returns false when starting the remote program fails' {
        Mock -ModuleName remotemgmt Invoke-Command { throw 'start failed' }

        $result = Start-RemoteProgram -ComputerName 'pc01' -AppPath 'C:\missing.exe' -ArgumentList ''

        $result | Should -Be $false
    }
}

Describe 'Get-WinBuild' {
    It 'returns Windows product and build information' {
        Mock -ModuleName remotemgmt Invoke-Command {
            [pscustomobject]@{ ProductName = 'Windows'; DisplayVersion = '23H2'; UBR = 1000 }
        }

        $result = Get-WinBuild -ComputerName 'pc01'

        $result.ProductName | Should -Be 'Windows'
        $result.DisplayVersion | Should -Be '23H2'
        $result.UBR | Should -Be 1000
        Should -Invoke -CommandName Invoke-Command -ModuleName remotemgmt -Times 1 -Exactly -ParameterFilter { $ComputerName -eq 'pc01' }
    }

    It 'returns false when querying the remote registry fails' {
        Mock -ModuleName remotemgmt Invoke-Command { throw 'registry unavailable' }

        $result = Get-WinBuild -ComputerName 'pc01'

        $result | Should -Be $false
    }
}

Describe 'Get-InstalledWindowsUpdate' {
    It 'returns the update list produced by the remote command' {
        Mock -ModuleName remotemgmt Invoke-Command {
            [pscustomobject]@{ Name = 'Cumulative Update for Windows' }
            [pscustomobject]@{ Name = '.NET Runtime' }
        }

        $result = @(Get-InstalledWindowsUpdate -ComputerName 'pc01')

        $result | Should -HaveCount 2
        $result[0].Name | Should -Be 'Cumulative Update for Windows'
        $result[1].Name | Should -Be '.NET Runtime'
        Should -Invoke -CommandName Invoke-Command -ModuleName remotemgmt -Times 1 -Exactly -ParameterFilter { $ComputerName -eq 'pc01' }
    }

    It 'returns false when querying remote updates fails' {
        Mock -ModuleName remotemgmt Invoke-Command { throw 'package provider unavailable' }

        $result = Get-InstalledWindowsUpdate -ComputerName 'pc01'

        $result | Should -Be $false
    }
}

Describe 'Install-MsiOnRemotePC' {
    It 'installs the MSI when the computer is reachable' {
        Mock -ModuleName remotemgmt Test-Connection { $true }
        Mock -ModuleName remotemgmt Invoke-Command {}

        $result = Install-MsiOnRemotePC -ComputerName 'pc01' -MsiPath 'C:\Temp\app.msi' -MsiArgs ' /quiet'

        $result | Should -Be $true
        Should -Invoke -CommandName Invoke-Command -ModuleName remotemgmt -Times 1 -Exactly -ParameterFilter {
            $ComputerName -eq 'pc01' -and $ErrorAction -eq 'Stop'
        }
    }

    It 'returns false and skips installation when the computer is unreachable' {
        Mock -ModuleName remotemgmt Test-Connection { $false }
        Mock -ModuleName remotemgmt Invoke-Command {}

        $result = Install-MsiOnRemotePC -ComputerName 'pc01' -MsiPath 'C:\Temp\app.msi' -MsiArgs ' /quiet'

        $result | Should -Be $false
        Should -Invoke -CommandName Invoke-Command -ModuleName remotemgmt -Times 0 -Exactly
    }

    It 'returns false when the remote installation fails' {
        Mock -ModuleName remotemgmt Test-Connection { $true }
        Mock -ModuleName remotemgmt Invoke-Command { throw 'installation failed' }

        $result = Install-MsiOnRemotePC -ComputerName 'pc01' -MsiPath 'C:\Temp\app.msi' -MsiArgs ' /quiet'

        $result | Should -Be $false
    }
}

Describe 'Find-KB-onRemotePC' {
    It 'returns the matching hotfix information' {
        Mock -ModuleName remotemgmt Invoke-Command {
            [pscustomobject]@{ HotFixID = 'KB123456'; InstalledOn = [datetime]'2026-01-01' }
        }

        $result = Find-KB-onRemotePC -ComputerName 'pc01' -KB 'KB123456'

        $result.HotFixID | Should -Be 'KB123456'
        $result.InstalledOn | Should -Be ([datetime]'2026-01-01')
        Should -Invoke -CommandName Invoke-Command -ModuleName remotemgmt -Times 1 -Exactly -ParameterFilter { $ComputerName -eq 'pc01' }
    }

    It 'returns false when the remote hotfix query fails' {
        Mock -ModuleName remotemgmt Invoke-Command { throw 'hotfix not found' }

        $result = Find-KB-onRemotePC -ComputerName 'pc01' -KB 'KB123456'

        $result | Should -Be $false
    }
}

Describe 'Remove-AppOnRemotePC' {
    It 'removes the application when the computer is reachable' {
        Mock -ModuleName remotemgmt Test-Connection { $true }
        Mock -ModuleName remotemgmt Invoke-Command {}

        $result = Remove-AppOnRemotePC -ComputerName 'pc01' -App 'Example App'

        $result | Should -Be $true
        Should -Invoke -CommandName Invoke-Command -ModuleName remotemgmt -Times 1 -Exactly -ParameterFilter {
            $ComputerName -eq 'pc01' -and $ErrorAction -eq 'Stop'
        }
    }

    It 'returns false and skips removal when the computer is unreachable' {
        Mock -ModuleName remotemgmt Test-Connection { $false }
        Mock -ModuleName remotemgmt Invoke-Command {}

        $result = Remove-AppOnRemotePC -ComputerName 'pc01' -App 'Example App'

        $result | Should -Be $false
        Should -Invoke -CommandName Invoke-Command -ModuleName remotemgmt -Times 0 -Exactly
    }

    It 'returns false when remote removal fails' {
        Mock -ModuleName remotemgmt Test-Connection { $true }
        Mock -ModuleName remotemgmt Invoke-Command { throw 'uninstall failed' }

        $result = Remove-AppOnRemotePC -ComputerName 'pc01' -App 'Example App'

        $result | Should -Be $false
    }
}

Describe 'Get-AppFromRemotePC' {
    It 'returns application name and version when the computer is reachable' {
        Mock -ModuleName remotemgmt Test-Connection { $true }
        Mock -ModuleName remotemgmt Invoke-Command {
            [pscustomobject]@{ Name = 'Example App'; Version = '2.0' }
        }

        $result = Get-AppFromRemotePC -ComputerName 'pc01' -App 'Example App'

        $result.Name | Should -Be 'Example App'
        $result.Version | Should -Be '2.0'
        Should -Invoke -CommandName Invoke-Command -ModuleName remotemgmt -Times 1 -Exactly -ParameterFilter {
            $ComputerName -eq 'pc01' -and $ErrorAction -eq 'Stop'
        }
    }

    It 'returns false and skips the lookup when the computer is unreachable' {
        Mock -ModuleName remotemgmt Test-Connection { $false }
        Mock -ModuleName remotemgmt Invoke-Command {}

        $result = Get-AppFromRemotePC -ComputerName 'pc01' -App 'Example App'

        $result | Should -Be $false
        Should -Invoke -CommandName Invoke-Command -ModuleName remotemgmt -Times 0 -Exactly
    }

    It 'returns false when the remote application lookup fails' {
        Mock -ModuleName remotemgmt Test-Connection { $true }
        Mock -ModuleName remotemgmt Invoke-Command { throw 'package lookup failed' }

        $result = Get-AppFromRemotePC -ComputerName 'pc01' -App 'Example App'

        $result | Should -Be $false
    }
}
