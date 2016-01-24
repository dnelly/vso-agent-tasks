# also add test for short-circuit case.
[CmdletBinding()]
param()

# Arrange.
. $PSScriptRoot\..\..\lib\Initialize-Test.ps1
. $PSScriptRoot\..\..\..\Tasks\PublishSymbols\PublishHelpers\CommonFunctions.ps1
. $PSScriptRoot\..\..\..\Tasks\PublishSymbols\PublishHelpers\PublishFunctions.ps1
Write-Verbose ($script:share = [System.IO.Path]::Combine($env:TMP, ([System.IO.Path]::GetRandomFileName())))
$pdbFiles = 'Some PDB file 1', 'Some PDB file 2'
$script:product = 'Some product'
$script:version = 'Some version'
$maximumWaitTime = [timespan]::FromSeconds(2)
$semaphoreMessage = 'Some semaphore message'
$artifactName = 'Some artifact name'
$script:responseFile = "$share\responseFile.txt"
Register-Mock New-ResponseFile { [System.IO.File]::WriteAllText($script:responseFile, 'Some response file content') ; $script:responseFile }
$script:semaphore = New-Object psobject
Register-Mock Lock-Semaphore { $script:semaphore }
Register-Mock Get-SymStorePath { 'Some path to symstore.exe'}
Register-Mock Invoke-VstsTool
Register-Mock Get-LastTransactionId { 'Some last transaction ID' }
Register-Mock Unlock-Semaphore
Register-Mock Get-ArtifactName { 'Some different artifact name' }
Register-Mock Write-VstsAssociateArtifact
try {
    $null = [System.IO.Directory]::CreateDirectory($share)

    # Act.
    Invoke-PublishSymbols -PdbFiles $pdbFiles -Share $share -Product $product -Version $version -MaximumWaitTime $maximumWaitTime -SemaphoreMessage $semaphoreMessage -ArtifactName $artifactName -ErrorVariable actualErrors

    # Assert.
    Assert-WasCalled New-ResponseFile -- -PdbFiles $pdbFiles
    Assert-WasCalled Lock-Semaphore -Share $share -MaximumWaitTime ([timespan]::FromMinutes(1)) -SemaphoreMessage $semaphoreMessage
    Assert-WasCalled Invoke-VstsTool -- -FileName 'Some path to symstore.exe' -Arguments "add /f ""@$script:responseFile"" /s ""$script:share"" /t ""$script:product"" /v ""$script:version""" -WorkingDirectory ([System.IO.Path]::GetTempPath())
    Assert-WasCalled Unlock-Semaphore -- $semaphore
    Assert-WasCalled Get-ArtifactName -- -ArtifactName $artifactName -LastTransactionId 'Some last transaction ID'
    Assert-WasCalled Write-VstsAssociateArtifact -ParametersEvaluator {
        $Name -eq 'Some different artifact name' -and
        $Path -eq $script:share -and
        $Type -eq 'SymbolStore' -and
        $Properties['TransactionId'] -eq 'Some last transaction ID'
    }
    Assert-AreEqual $false (Test-Path -LiteralPath $responseFile)
} finally {
    if (Test-Path -LiteralPath $share) { Remove-Item -LiteralPath $share -Recurse }
}