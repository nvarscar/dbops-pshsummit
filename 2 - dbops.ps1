#region cleanup
$password = 'dbatools.IO'
$sPassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object pscredential 'sqladmin', $sPassword

### Cleanup
Function cleanup { 
    $null = Remove-DbaDatabase -SqlInstance localhost -Database dbops -Confirm:$false -SqlCredential $cred
    Invoke-DbaQuery -SqlInstance localhost -Query "CREATE DATABASE dbops" -SqlCredential $cred
    New-Item -Path C:\Lab\dbops, C:\Lab\packages -ItemType Directory -Force | Out-Null
    Remove-Item C:\Lab\dbops\*, C:\Lab\packages\* -Recurse
    Copy-Item 'C:\Lab\builds\1. DB\*' C:\Lab\dbops -Recurse
    
}
cleanup
Reset-DBODefaultSetting -All
#endregion cleanup

#region DEMO1


# Settings
##List default settings
Get-DBODefaultSetting


##Set default settings
Set-DBODefaultSetting -Name SqlInstance -Value localhost
Set-DBODefaultSetting -Name database -Value dbops
Set-DBODefaultSetting -Name Credential -Value $cred

# Simple deployments
## Execute sample script
Set-Location C:\
Install-DBOSqlScript -ScriptPath C:\Lab\dbops -SqlInstance localhost -Database dbops

## Validation
Invoke-DBOQuery -Query "SELECT schema_name(schema_id) as [Schema], name FROM sys.tables" | Out-GridView
Invoke-DBOQuery -Query "SELECT * FROM SchemaVersions" | Out-GridView


## Add procedures to the list of deployment scripts
cleanup
Set-Location C:\Lab\dbops
$result = Install-DBOSqlScript -ScriptPath .\*
$result | Select-Object *
Copy-Item 'C:\Lab\builds\7. Stored Procedures' C:\Lab\dbops -Recurse -PassThru
Install-DBOSqlScript -ScriptPath .\*


#endregion DEMO1


#region DEMO2

# Packages and build system
## Building a package
cleanup
Set-Location C:\Lab\packages
$package = New-DBOPackage -Name dbopsPackage -ScriptPath C:\Lab\dbops\* -Build 1.0
$package

## Adding builds to the package
$newPackage = Add-DBOBuild -Path $package -ScriptPath 'C:\Lab\builds\7. Stored Procedures' -Build 2.0
$newPackage | Select-Object *
$newPackage | Get-Member
$build = $newPackage.GetBuild('2.0')
$build | Format-List
$build | Get-Member
$build.Scripts | Select-Object *
$newPackage.GetBuild('1.0').Scripts[4].GetContent()


## Deploying package to a custom versioning table
$results = $newPackage | Install-DBOPackage -SchemaVersionTable dbo.DeploymentLog
$results | Select-Object *



# Configuration
## Package configuration
Get-DBOPackage .\dbopsPackage.zip | Get-DBOConfig
Update-DBOConfig .\dbopsPackage.zip -Configuration @{DeploymentMethod='SingleTransaction'}
Get-DBOPackage .\dbopsPackage.zip | Get-DBOConfig

## Custom configurations
$config = @{ DeploymentMethod = 'TransactionPerFile' }
Install-DBOPackage .\dbopsPackage.zip -Configuration $config

## Configuration files
$config = Get-DBOPackage C:\Lab\packages\dbopsPackage.zip | Get-DBOConfig
$config.SchemaVersionTable
$config.SchemaVersionTable = 'dbo.DeploymentLog'
$config | Export-DBOConfig .\dbops.json 
notepad .\dbops.json
Install-DBOPackage .\dbopsPackage.zip -Configuration .\dbops.json


## Registering the package without deploying
cleanup
$package = New-DBOPackage -Name dbopsPackage -ScriptPath C:\Lab\dbops\* -Build 1.0
Register-DBOPackage $package
Install-DBOPackage $package


#endregion DEMO2


#region DEMO3


# CI/CD stuff
cleanup
Get-ChildItem .

## Create a new package using continuous integration features and automatic versioning
Invoke-DBOPackageCI -Name .\dbopsPackage.zip -ScriptPath C:\Lab\dbops\* -Version 0.5 | Select-Object Name, Builds, Version

## Store package in a repository
$dir = New-Item C:\Lab\packages\Repo -ItemType Directory
Publish-DBOPackageArtifact -Path .\dbopsPackage.zip -Repository $dir

## Augment the package with a new build using same source folder
Copy-Item 'C:\Lab\builds\7. Stored Procedures' C:\Lab\dbops -Recurse -PassThru
Invoke-DBOPackageCI -Name .\dbopsPackage.zip -ScriptPath C:\Lab\dbops\* | Select-Object Name, Builds, Version
Get-DBOPackage .\dbopsPackage.zip | Select-Object -ExpandProperty Builds

### Essentially, the same as using 
Add-DBOBuild  -Name .\dbopsPackage.zip -ScriptPath C:\Lab\dbops\* -Build 0.5.3 -Type New | Select-Object Name, Builds, Version

## Store new version in a repository
Publish-DBOPackageArtifact -Path .\dbopsPackage.zip -Repository $dir
Invoke-Item $dir

## Deploy the package from a repository
Get-DBOPackageArtifact -Name dbopsPackage -Repository $dir -Version 0.5.1
Get-DBOPackageArtifact -Name dbopsPackage -Repository $dir | Install-DBOPackage #| Send-DBOMailMessage -PassThru

#endregion DEMO3


#region DB types
Reset-DBODefaultSetting -All
$pgCred = [pscredential]::new('postgres',$sPassword)
Invoke-DBOQuery -Type PostgreSQL -SqlInstance localhost -Query "SELECT version()" -Credential $pgCred
Invoke-DBOQuery -Type PostgreSQL -SqlInstance localhost -Credential $pgCred -Interactive

#endregion DB types