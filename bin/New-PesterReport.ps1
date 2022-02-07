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


function New-PesterReport{
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

    begin {
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose "[Begin]   $function"
        Import-Module PSHTML
        if(Test-Path -Path $Inputfile){
            $TestInputFile = Get-Item $InputFile
            $BaseInputFile = $TestInputFile.BaseName
            switch($TestInputFile.Extension){
                '.junitxml' {
                    $InputObject = ConvertFrom-PesterJUnitXml -InputFile $Inputfile #-Verbose
                    Write-Verbose $Inputfile
                }
                '.nunitxml' {
                    Write-Verbose $Inputfile
                    $InputObject = ConvertFrom-PesterJUnitXml -InputFile $Inputfile #-Verbose
                    $InputObject
                    exit
                }
            }
        }else{
            $InputFile = Read-Host -Prompt "Could not find $InputFile, please enter a new file"
        }
    }
    process {
        Write-Verbose "[Process] $function"

        #region Variables
        $PieCanvasID         = "piecanvas"
        $DoughnutCanvasID    = "Doughnutcanvas"
        $BarCanvasID         = "barcanvas"
        $ContinerStyle       = 'container' #'container-fluid'

        #region header
        $HeaderTitle        = "PSHTML-Reports"
        $HeaderCaption1     = "PSHTML/> $($function)"
        #endregion

        #region body
        $BodyDescription    = "List the result from Pester Tests"
        #endregion

        #region diagrams
        $TestSummary            = $InputObject | Select-Object TotalCount, FailedCount, PassedCount, SkippedCount, NotRunCount
        $PercentResult          = (100 * ($TestSummary.FailedCount + $TestSummary.SkippedCount + $TestSummary.NotRunCount)) / $TestSummary.TotalCount
        if($PercentResult -le 30){$CardColor = 'red'}
        if($PercentResult -le 60){$CardColor = 'orange'}
        if($PercentResult -gt 60){$CardColor = 'green'}
        $DiagramCaptionLeft     = 'Test Summary'
        $DiagramCaptionMiddle   = 'Test Summary'
        $DiagramCaptionRight    = 'Pass Percentage'
        $BodyCaptionDiagram     = "Summary"
        $DiagramBackgroundColor = @("green","red","yellow","orange")
        #endregion

        #region table
        $ShowPassedTests  = $false
        $BodyCaptionTable = "Test Results"
        $TableClasses     = 'table table-sm table-hover' #"table table-responsive table-sm table-hover"
        $TableHeaders     = "thead-light"
        $TableStyle       = "width:100%"
        $topNav           = a -Class "btn btn-outline-secondary btn-sm" -href "#Summary" "Summary" -Attributes @{"role"="button"}
        $TableColunms     = @('TestName','Description','Message')

        if($InputObject.Passed){
            $Passed = foreach($item in $InputObject.Passed){
                [PSCustomObject]@{
                    TestName    = $item.TestName
                    Description = $item.Description
                    Message     = $item.Message
                }
            }
        }

        if($InputObject.Failed){
            $Failed = foreach($item in $InputObject.Failed){
                [PSCustomObject]@{
                    TestName    = $item.TestName
                    Description = $item.Description
                    Message     = $item.Message
                }
            }
        }

        if($InputObject.Skipped){
            $Skipped = foreach($item in $InputObject.Skipped){
                [PSCustomObject]@{
                    TestName    = $item.TestName
                    Description = $item.Description
                    Message     = $item.Message
                }
            }
        }

        if($InputObject.NotRun){
            $NotRun = foreach($item in $InputObject.NotRun){
                [PSCustomObject]@{
                    TestName    = $item.TestName
                    Description = $item.Description
                    Message     = $item.Message
                }
            }
        }
        #endregion

        #region footer
        $FooterSummary = $InputObject | Select-Object ExecutedAt, Result, Duration, TestComputer
        #endregion

        #endregion

        #region HTML
        $HTML = html {

            #region header                       
            head {
                meta -charset 'UTF-8'
                meta -name 'author' -content "Martin Walther"   
                Link -href "style/style.css" -rel stylesheet
                Script -src "assets/Jquery/jquery.min.js"
                Script -src "assets/BootStrap/bootstrap.min.js"
     
                title $HeaderTitle
                Write-PSHTMLAsset -Name Jquery
                Write-PSHTMLAsset -Name BootStrap
                Write-PSHTMLAsset -Name Chartjs
            } 
            #endregion
              
            #region body
            body {

                # <!-- Do not change the nav -->
                nav -class "navbar navbar-expand-sm bg-dark navbar-dark sticky-top" -content {
                    a -class "navbar-brand" -href "#" -content {'PSHPReporting'}
                    # <!-- Toggler/collapsibe Button -->
                    button -class "navbar-toggler" -Attributes @{
                        "type"="button"
                        "data-toggle"="collapse"
                        "data-target"="#collapsibleNavbar"
                    } -content {
                        span -class "navbar-toggler-icon"
                    }

                    # <!-- Navbar links -->
                    div -class "collapse navbar-collapse" -id "collapsibleNavbar" -Content {

                        ul -class "navbar-nav" -content {
            
                            #FixedLinks
                            li -class "nav-item" -content {
                                a -class "nav-link" -href "https://pshtml.readthedocs.io/" -Target _blank -content { "PSHTML" }
                            }

                            li -class "nav-item" -content {
                                a -class "nav-link" -href "https://pester.dev/" -Target _blank -content { "Pester" }
                            }
                    
                            li -class "nav-item" -content {
                                a -class "nav-link" -href "https://getbootstrap.com/" -Target _blank -content { "Bootstrap" }
                            }
                    
                            li -class "nav-item" -content {
                                a -class "nav-link" -href "https://www.w3schools.com/" -Target _blank -content { "w3schools" }
                            }
                    
                        }
            
                    }

                }

                article -id "Content" -Content {

                    div -id "SiteContent" -Class $ContinerStyle {

                        article -id "Diagrams" -Content {

                            div -Class $ContinerStyle {

                                div -Class "row align-items-center" {

                                    div -Class "col-sm" {
                                        canvas -Height 300px -Width 300px -Id $DoughnutCanvasID {}
                                    }
                                    div -Class "col-sm" {
                                        canvas -Height 300px -Width 300px -Id $BarCanvasID {}
                                    }
                                    div -Class "col-sm" {
                                        div -Class "card" -id "Summary" -Style "height: 250px; width:250px; background-color:$CardColor" {
                                            div -Class "card-body" {
                                                div -Class 'card-title text-center' {
                                                    h3 -Class "display-5 font-weight-bold" -Style "color:white" { 
                                                        $DiagramCaptionRight
                                                    }
                                                }
                                                div -Class 'card-text text-center' {
                                                    h4 -Class "display-4 font-weight-bold" -Style "color:white" { 
                                                        "$($PercentResult)%"
                                                    }
                                                }
                                            }
                                        }
                                    }
                            
                                    script -content {
                                        #Doughnut Chart
                                        $data   = @($TestSummary.PassedCount, $TestSummary.FailedCount, $TestSummary.NotRunCount, $TestSummary.SkippedCount)
                                        $labels = @('PassedCount', 'FailedCount', 'NotRunCount', 'SkippedCount')
                                        $dsd1   = New-PSHTMLChartDoughnutDataSet -Data $data -backgroundcolor $DiagramBackgroundColor
                                        New-PSHTMLChart -Type doughnut -DataSet $dsd1 -title $DiagramCaptionLeft -Labels $labels -CanvasID $DoughnutCanvasID 

                                        #Bar Chart
                                        $dsb1 = New-PSHTMLChartBarDataSet -Data $TestSummary.TotalCount   -label 'TotalCount'   -backgroundColor 'blue'   -hoverBackgroundColor 'blue'   -hoverBorderColor 'black'
                                        $dsb2 = New-PSHTMLChartBarDataSet -Data $TestSummary.FailedCount  -label 'FailedCount'  -backgroundColor 'red'    -hoverBackgroundColor 'red'    -hoverBorderColor 'black'
                                        $dsb3 = New-PSHTMLChartBarDataSet -Data $TestSummary.PassedCount  -label 'PassedCount'  -backgroundColor 'green'  -hoverBackgroundColor 'green'  -hoverBorderColor 'black'
                                        $dsb4 = New-PSHTMLChartBarDataSet -Data $TestSummary.SkippedCount -label 'SkippedCount' -backgroundColor 'orange' -hoverBackgroundColor 'orange' -hoverBorderColor 'black'
                                        $dsb5 = New-PSHTMLChartBarDataSet -Data $TestSummary.NotRunCount  -label 'NotRunCount'  -backgroundColor 'yellow' -hoverBackgroundColor 'yellow' -hoverBorderColor 'black'
                                        New-PSHTMLChart -type bar -DataSet @($dsb1, $dsb2, $dsb3, $dsb4, $dsb5) -title $DiagramCaptionMiddle -Labels 'Tests as Bar Chart' -CanvasID $BarCanvasID 

                                        #Pie Chart
                                        $data   = @($TestSummary.PassedCount, $TestSummary.FailedCount)
                                        $labels = @('PassedCount', 'FailedCount')
                                        $dsp1   = New-PSHTMLChartPieDataSet -Data $data -label 'Tests as Pie Chart' -BackgroundColor $DiagramBackgroundColor
                                        New-PSHTMLChart -type pie -DataSet $dsp1 -title $DiagramCaptionRight -Labels $labels -CanvasID $PieCanvasID 
                                    }
                                }
                            }
                        }

                        article -id "Table" -Content {
                            if($TestSummary.FailedCount -gt 0 -or $TestSummary.SkippedCount -gt 0 -or $TestSummary.NotRunCount -gt 0){
                                div -Class $ContinerStyle {

                                    if($ShowPassedTests){
                                        if($TestSummary.FailedCount -gt 0){
                                            if($Passed){
                                                p {
                                                    h3 'Passed'
                                                }        
                                                ConvertTo-PSHtmlTable -Object $Passed -Properties $TableColunms -TableClass $TableClasses -TheadClass $TableHeaders -TableStyle $TableStyle
                                            }
                                        }
                                    }

                                    if($TestSummary.FailedCount -gt 0){
                                        if($Failed){
                                            p {
                                                h3 'Failed'
                                            }        
                                            ConvertTo-PSHtmlTable -Object $Failed -Properties $TableColunms -TableClass $TableClasses -TheadClass $TableHeaders -TableStyle $TableStyle
                                        }
                                    }

                                    if($TestSummary.SkippedCount -gt 0){
                                        if($Skipped){
                                            p {
                                                h3 'Skipped'
                                            }        
                                            ConvertTo-PSHtmlTable -Object $Skipped -Properties $TableColunms -TableClass $TableClasses -TheadClass $TableHeaders  -TableStyle $TableStyle
                                        }
                                    }

                                    if($TestSummary.NotRunCount -gt 0){
                                        if($NotRun){
                                            p {
                                                h3 'NotRun'
                                            }        
                                            ConvertTo-PSHtmlTable -Object $NotRun -Properties $TableColunms -TableClass $TableClasses -TheadClass $TableHeaders  -TableStyle $TableStyle
                                        }
                                    }
                                    p {
                                        $topNav
                                    } 
                                }
                            }   
                        }
                    }

                }
            }
            #endregion body

            #region footer
            div -Class "container-fluid" {
                Footer {

                    hr

                    div -Class "container" {
                        div -Class "row align-items-center" {
                            div -Class "col-md" {
                                p {"Executet at: $(Get-Date $FooterSummary.ExecutedAt -f 'yyyy-MM-dd HH:mm:ss')"}
                            }
                            div -Class "col-md" {
                                p {"Duration: $($FooterSummary.Duration)"}
                            }
                            div -Class "col-md" {
                                p {"Test: $($BaseInputFile)"}
                            }
                        }
                    }
            
                }
            }
            #endregion

        }
        #endregion  
    }

    end{
        Write-Verbose "[End]     $function"
        $Path = Join-Path -Path $($PSScriptRoot).Trim('bin') -ChildPath ("$($BaseInputFile).html")
        $Html | Out-File -FilePath $Path -Encoding utf8 -Force
        Start-Process $Path -PassThru
    }
}

Get-ChildItem $($PSScriptRoot).Replace('bin','data') -Filter '*.JUnitXml' | ForEach-Object {
    $Inputfile = Get-ChildItem -Path $_.FullName
    New-PesterReport -InputFile $Inputfile #-Verbose
}
