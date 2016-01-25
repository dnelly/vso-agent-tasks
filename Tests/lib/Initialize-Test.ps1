[CmdletBinding()]
param()

Write-Verbose "Initializing test helpers."
$ErrorActionPreference = 'Stop'
$PSModuleAutoloadingPreference = 'None'
if (!(Get-Module | Where-Object { $_.Name -eq 'Microsoft.PowerShell.Management' })) {
    Write-Verbose "Importing module: Microsoft.PowerShell.Management"
    Import-Module 'Microsoft.PowerShell.Management' -Verbose:$false
}

Import-Module $PSScriptRoot\TestHelpersModule -Verbose:$false
Register-Mock Import-Module

# Temporary mocks for common VSTS task SDK. Need to actually import the module instead.
Register-Mock Get-VstsLocString { $OFS = ' ' ; "$($args[1]) $($args[3])".Trim() }
Register-Mock Import-VstsLocStrings { if (!$args.Count) { throw 'Missing arguments.' } }
Register-Mock Trace-VstsEnteringInvocation { if (!$args.Count) { throw 'Missing arguments.' } }
Register-Mock Trace-VstsLeavingInvocation { if (!$args.Count) { throw 'Missing arguments.' } }

# This is a mock implementation for the legacy module cmdlet.
function Get-LocalizedString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        
        [object[]]$ArgumentList)

    if (@($ArgumentList).Count -eq 0) { # Workaround for Powershell quirk, passing a single null argument to a list parameter.
        $ArgumentList = @( $null )
    }

    ($Key -f $ArgumentList)
}
