[CmdletBinding()]
param([switch]$Legacy)

Write-Verbose "Initializing test helpers."
$ErrorActionPreference = 'Stop'
$PSModuleAutoloadingPreference = 'None'
Write-Verbose "Importing module: Microsoft.PowerShell.Management"
Import-Module 'Microsoft.PowerShell.Management' -Verbose:$false
Write-Verbose "Importing module: TestHelpersModule"
Import-Module $PSScriptRoot\TestHelpersModule -Verbose:$false
Register-Mock Import-Module
if (!$Legacy) {
    # Mock implementations for common VSTS task SDK functions.
    function Get-VstsLocString {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true, Position = 1)]
            [string]$Key,
            [Parameter(Position = 2)]
            [object[]]$ArgumentList = @( ))

        $OFS = ' '
        "$Key$(if ($ArgumentList.Count) { " $ArgumentList" })"
    }

    function Import-VstsLocStrings { }

    function Trace-VstsEnteringInvocation {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [System.Management.Automation.InvocationInfo]$InvocationInfo,
            [string[]]$Parameter = '*')

        Write-Verbose "Entering $(Get-InvocationDescription $InvocationInfo)."
        $OFS = ", "
        if ($InvocationInfo.BoundParameters.Count -and $Parameter.Count) {
            if ($Parameter.Count -eq 1 -and $Parameter[0] -eq '*') {
                foreach ($key in $InvocationInfo.BoundParameters.Keys) {
                    Write-Verbose " $($key): '$($InvocationInfo.BoundParameters[$key])'"
                }
            } else {
                foreach ($key in $InvocationInfo.BoundParameters.Keys) {
                    foreach ($p in $Parameter) {
                        if ($key -like $p) {
                            Write-Verbose " $($key): '$($InvocationInfo.BoundParameters[$key])'"
                            break
                        }
                    }
                }
            }
        }

        if (@($InvocationInfo.UnboundArguments).Count) {
            for ($i = 0 ; $i -lt $InvocationInfo.UnboundArguments.Count ; $i++) {
                Write-Verbose " args[$i]: '$($InvocationInfo.UnboundArguments[$i])'"
            }
        }
    }

    function Trace-VstsLeavingInvocation {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [System.Management.Automation.InvocationInfo]$InvocationInfo)

        Write-Verbose "Leaving $(Get-InvocationDescription $InvocationInfo)."
    }
}

# This is a mock implementation for the legacy module cmdlet.
# TODO: Encapsulate this in an "if ($Legacy) { [...] }" block after the legacy switch is added to all of the legacy tests.
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
