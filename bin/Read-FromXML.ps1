<#
    Read from JUnitXml or NUnitXml
    https://jdhitsolutions.com/blog/powershell/7409/importing-pester-results-into-powershell/
    https://gist.github.com/jdhitsolutions/e350a5e4a338a241e6a2ae31d683f6cc

    $InputFile = 'D:\github.com\PrivateStuff\PesterReport\data\Test-PsNetTools_JUnit.JUnitXml'
    $PesterJUnitXml = ConvertFrom-PesterJUnitXml -InputFile $InputFile
    $PesterJUnitXml

    $PesterJSON = Get-Content 'D:\github.com\PrivateStuff\PesterReport\data\Test-PsNetTools_JSON.json' | Convertfrom-json
    $PesterJSON

    $InputFile = 'D:\github.com\PrivateStuff\PesterReport\data\Test-PsNetTools_NUnit.NUnitXml'
    $PesterNUnitXml = ConvertFrom-PesterNUnitXml -InputFile $InputFile
    $PesterNUnitXml
#>
function ConvertFrom-PesterNUnitXml{
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [String]$InputFile
    )

    begin{
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "[Begin]   $function"
    }

    process {
        Write-Verbose "[Process] $function"

        if(Test-Path -Path $InputFile){
            [xml]$doc = Get-Content -path $InputFile
            if ($doc.'test-results'.noNamespaceSchemaLocation -match "nunit") {    
                Write-Host "It's NUnit format!"   

                $PesterFileDate = (Get-Item -Path $InputFile).CreationTime.ToString().trim()
                $doc.'test-results'.'test-suite'.results.'test-suite' | ForEach-Object {
                    $PesterFile     = $_.name
                }

                $PesterResult = [PSCustomObject]@{
                    PesterFile   = $PesterFile
                } 
            }
        }
    }

    end {
        Write-Verbose "[End]     $function"
        return $PesterResult
    }
}

function ConvertFrom-PesterJUnitXml{
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [String]$InputFile
    )

    begin{
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "[Begin]   $function"
    }

    process {
        Write-Verbose "[Process] $function"

        if(Test-Path -Path $InputFile){
            [xml]$doc = Get-Content -path $InputFile
            if ($doc.testsuites.noNamespaceSchemaLocation -match "junit") {        
                
                $PesterFileDate = (Get-Item -Path $InputFile).CreationTime.ToString().trim()
                $doc.testsuites.testsuite | ForEach-Object {
                    $PesterFile     = $_.name
                    $TestComputer   = $_.hostname
                    $TotalCount     = [int]$_.tests
                    $PassedCount    = ([int]$_.tests) - ([int]($_.failures) + [int]($_.skipped) + [int]($_.disabled) + ([int]$_.errors))
                    $ErrorCount     = [int]$_.errors
                    $FailedCount    = [int]$_.failures
                    $SkippedCount   = [int]$_.skipped
                    $NotRunCount    = [int]$_.disabled
                    $Duration       = $_.time
                    $Result         = if($TotalCount -ne $PassedCount){'Failed'}else{'Passed'}
                }

                $Tests = $doc.testsuites.testsuite.testcase | ForEach-Object {
                    if($_.status -match "Failed"){
                        $null = $_.failure.message -match '(?<=^)(.*)(?=\.)'
                        $Message = $matches[0]
                    }elseif($_.status -match "Passed"){
                        $Message = "Success"
                    }else{
                        $Message = $null
                    }
                    $TestName = $_.name -split '\.'
                    [PSCustomObject]@{
                        TestName    = $TestName[0]
                        Description = $TestName[1]
                        Status      = $_.status
                        Duration    = $_.time
                        Message     = $Message
                    }
                }
        
                $PesterResult = [PSCustomObject]@{
                    PesterFile   = $PesterFile
                    ExecutedAt   = $PesterFileDate
                    TestComputer = $TestComputer
                    TotalCount   = $TotalCount
                    PassedCount  = $PassedCount
                    FailedCount  = $FailedCount
                    ErrorCount   = $ErrorCount
                    SkippedCount = $SkippedCount
                    NotRunCount  = $NotRunCount
                    Duration     = $Duration
                    Result       = $Result
                    Passed       = ($Tests).Where({ $_.status -match "Passed" })  | Select-Object TestName, Description, Status, Message, Duration
                    Failed       = ($Tests).Where({ $_.status -match "Failed" })  | Select-Object TestName, Description, Status, Message, Duration
                    Skipped      = ($Tests).Where({ $_.status -match "Skipped" }) | Select-Object TestName, Description, Status, Message, Duration
                    NotRun       = ($Tests).Where({ $_.status -match "NotRun" })  | Select-Object TestName, Description, Status, Message, Duration
                    Tests        = $Tests
                }                
        
            }else{
                Write-Warning "Input is not in the JUnit-format!"
            }
        }
    }

    end {
        Write-Verbose "[End]     $function"
        return $PesterResult
    }  
}