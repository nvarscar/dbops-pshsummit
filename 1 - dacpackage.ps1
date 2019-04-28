# defining variables and authentication
$password = 'dbatools.IO'
$sPassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object pscredential 'sqladmin', $sPassword
$PSDefaultParameterValues = @{
    Disabled               = $false
    "*-Dba*:SqlCredential" = $cred
}

# define export options
$exportOptions = New-DbaDacOption -Type Dacpac -Action Export
$exportOptions.IgnorePermissions = $true
$exportOptions.IgnoreUserLoginMappings = $true

# export dacpac
$exportSplat = @{
    SqlInstance = 'localhost'
    Database    = 'Northwind'
    Path        = 'c:\backups'
    DacOption   = $exportOptions
}
$exportFile = Export-DbaDacPackage @exportSplat
$exportFile
Invoke-Item C:\Backups

# define publish options
$publishOptions = New-DbaDacOption -Type Dacpac -Action Publish
# ignore certain object types
$publishOptions.DeployOptions.ExcludeObjectTypes = 'Permissions', 'RoleMembership', 'Logins'
$publishOptions.DeployOptions.IgnorePermissions = $true
$publishOptions.DeployOptions.IgnoreUserSettingsObjects = $true
$publishOptions.DeployOptions.IgnoreLoginSids = $true
$publishOptions.DeployOptions.IgnoreRoleMembership = $true

# publish dacpac
$publishSplat = @{
    SqlInstance = 'localhost'
    Database    = 'Southstorms'
    Path        = $exportFile.Path
    DacOption   = $publishOptions
}
Publish-DbaDacPackage @publishSplat

# modify the table
Invoke-DbaQuery -SqlInstance localhost -Database Southstorms -Query 'ALTER TABLE Categories ADD NewCol int'

# re-deploy the package
Publish-DbaDacPackage @publishSplat