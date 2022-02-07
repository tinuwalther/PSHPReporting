# Table of Contents

- [PSHPReporting](#pshpreporting)
- [Folder structure](#folder-structure)
- [Usage with JUnitXML](#usage-with-junitxml)
- [Usage with NUnitXML](#usage-with-nunitxml)

# PSHPReporting

PSHPReporting - PowerShell PSHTML-based Pester Reporting

![PSHPReporting](./img/PSHPReporting.jpg)

[Top](#table-of-contents)

## Folder structure

````
.\PSHPREPORTING
|   README.md
|   Test-PsNetTools_JUnit.html
|   
+---bin
|       Invoke-PesterResult.Tests.ps1
|       New-PesterReport.ps1
|       Read-FromXML.ps1
|       
+---data
|       Test-PsNetTools_JSON.json
|       Test-PsNetTools_JUnit.JUnitXml
|       Test-PsNetTools_NUnit.NUnitXml
|
+---img
|       PSHPReporting.jpg
|
\---style
        style.css
````

### bin

Path to store the PowerShell-Scripts.

### data

Path to store the Inputfiles (JUnitXml, NUnitXml).

### img

Path to store Pictures/Images.

### style

Path to store CSS.

[Top](#table-of-contents)

## Usage with JUnitXML

````New-PesterReport.ps1```` use the JUnitXml file from a Pester Test. It ````ConvertFrom-PesterJUnitXml```` to a PSCustomObject and create a PSHTML-Page.

To create a JUnitXml run: 
````Invoke-Pester -Path .\ -OutputFile .\data\Test-PsNetTools.JUnitXml -OutputFormat JUnitXml````

To create a PSHTML-Page run: ````New-PesterReport.ps1````

[Top](#table-of-contents)

## Usage with NUnitXML

To create a NUnitXml run: 
````Invoke-Pester -Path .\ -OutputFile .\data\Test-PsNetTools.NUnitXml -OutputFormat NUnitXml````

To create a PSHTML-Page run: **Not yet implemented**

[Top](#table-of-contents)
