########################################
# Public functions.
########################################
function Invoke-PublishSymbols {
    [CmdletBinding()]
    param(
        [string[]]$PdbFiles,
        [Parameter(Mandatory = $true)]
        [string]$Share,
        [Parameter(Mandatory = $true)]
        [string]$Product,
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [Parameter(Mandatory = $true)]
        [timespan]$MaximumWaitTime,
        [Parameter(Mandatory = $true)]
        [string]$SemaphoreMessage,
        [string]$ArtifactName)

    Trace-VstsEnteringInvocation $MyInvocation
    try {
        if (!$PdbFiles.Count) {
            Write-Warning (Get-VstsLocString -Key NoFilesForPublishing)
            return
        }

        [string]$symbolsRspFile = ''
        try {
            $symbolsRspFile = New-ResponseFile
            $MaximumWaitTime = Get-ValidValue -Current $MaximumWaitTime -Minimum ([timespan]::FromMinutes(1)) -Maximum ([timespan]::FromHours(3))
            $semaphore = Lock-Semaphore -Share $Share -MaximumWaitTime $MaximumWaitTime -SemaphoreMessage $SemaphoreMessage
            try {
                $symstoreArgs = "add /f ""@$symbolsRspFile"" /s ""$Share"" /t ""$Product"" /v ""$Version"""
                Invoke-VstsTool -FileName (Get-SymStorePath) -Arguments $symstoreArgs -WorkingDirectory ([System.IO.Path]::GetTempPath()) 2>&1 |
                    ForEach-Object {
                        if ($_ -is [System.Management.Automation.ErrorRecord]) {
                            Write-Error $_
                        } else {
                            Write-Verbose $_
                        }
                    }
                $lastTransactionId = Get-LastTransactionId
            } finally {
                Unlock-Semaphore $semaphore
            }

            if (!$ArtifactName) {
                if ($lastTransactionId) {
                    $ArtifactName = $lastTransactionId
                } else {
                    $ArtifactName = [guid]::NewGuid().ToString() 
                }
            }

            Write-VstsAssociateArtifact -Name $ArtifactName -Path $Share -Type 'SymbolStore' -Properties @{
                TransactionId = $lastTransactionId
            }
        } finally {
            if ($symbolsRspFile) {
                [System.IO.File]::Delete($symbolsRspFile)
            }
        }
    } finally {
        Trace-VstsLeavingInvocation
    }
}

########################################
# Private functions.
########################################
function Get-LastTransactionId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Share)

    [string]$lastIdFileName = [System.IO.Path]::Combine($Share, '000Admin\lastid.txt')
    if (Test-Path -LiteralPath $lastIdFileName -PathType Leaf) {
        [System.IO.File]::ReadAllText($lastIdFileName).Trim()
    } else {
        Write-Warning (Get-VstsLocString -Key SymbolStoreLastIdTxtNotFoundAt0 -ArgumentList [System.IO.Path]::Combine($Share, "000Admin"))
    }
}

function New-ResponseFile {
    [CmdletBinding()]
    param()

    Trace-VstsEnteringInvocation $MyInvocation
    try {
        $symbolsRspFile = [System.IO.Path]::GetTempFileName()
        $sw = New-Object System.IO.StreamWriter([System.IO.File]::OpenWrite($symbolsRspFile))
        try {
            foreach ($pdbFile in $PdbFiles) {
                if (Test-Path -LiteralPath $PdbFile -PathType Leaf) {
                    $sw.WriteLine($pdbFile)
                }
            }
        } finally {
            $sw.Dispose()
        }

        $symbolsRspFile
    } finally {
        Trace-VstsLeavingInvocation $MyInvocation
    }
}
