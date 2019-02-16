param(
    [Parameter(Mandatory)]
    [Alias('h','uh')]
        [string] $UserHost,

    [Parameter()]
    [Alias('en')]
        [string] $ExeName,

    [Parameter()]
    [Alias('sn')]
        [string] $ServiceName,

    [Parameter()]
    [Alias('pn')]
        [string] $ProjectName,

    [Parameter()]
    [Alias('p')]
        [int] $Port = 22,

    [Parameter()]
        [switch] $SkipPublish
)

###
# REQUIREMENTS:
#   - Target machine
#     - Pwsh6 installed and configured under SSH
#     - Password-less sudo
#   - Client
#     - Run with Pwsh6
#     - ssh and scp in $env:Path
###

##
## Input
##

### Preset

$ErrorActionPreference = 'Stop'
$localAppRoot = './bin/publish/linux-service'
$destAppParent = '/opt'

### Functions

function run($sb) {& $sb; if (!$?) {throw "Error: $LASTEXITCODE"}}

### Types

class AppParams {
    [string] $ServiceName
    [string] $ExeName
    [string] $DestAppRoot
    [string] $UserName
    [string] $HostName
    [string] $ServiceFileContent
}

### Computed

if ($SkipPublish -and !$ServiceName) {throw 'ServiceName is mandatory when SkipPublish is present'}

if (!$ServiceName) {
    $projs = Get-Item *.csproj
    if ($ProjectName)
        {$ServiceName = $ProjectName}
    elseif ($projs.Length -eq 1)
        {$ServiceName = $projs[0].BaseName}
    else
        {$ServiceName = (Get-Location).Path -replace '^.*[\\/]([^\\/]+)[\\/]?$','$1'}
}
#if (!$ServiceName) {throw 'The project name cannot be determined'}

if (!$ExeName) {
    $ExeName = $ServiceName
}
#### Adjust the name to the Unix standards
$ServiceName = $ServiceName `
    -creplace '([A-Z][a-z]+)', ' $1' `
    -replace '\W', ' ' `
    -replace '\s+', '-' |
    ForEach-Object Trim '-', '/', '\' |
    ForEach-Object ToLower

if ($ServiceName -notmatch '^[-_\w]+$' -and $ServiceName.ToLower() -ne $ServiceName) {throw "The name is not a valid unit name"}

$destAppRoot = "$destAppParent/$ServiceName"
if ($destAppRoot.Trim('/') -eq $destAppParent.Trim('/')) {throw "Invalid target location"}

$userHostArr = $UserHost.Trim() -split '@'
if ($userHostArr.Length -ne 2 -or !$userHostArr[0] -or !$userHostArr[1]) {throw "UserHost requires the user@host format."}
$app = [AppParams]::new()
$app.ServiceName = $ServiceName
$app.ExeName = $ExeName
$app.UserName = $userHostArr[0]
$app.HostName = $userHostArr[1]
$app.DestAppRoot = $destAppRoot


##### /usr/bin/dotnet /opt/$ServiceName/$ServiceName.dll
##### User=$($app.UserName) // "/etc/systemd/user/$($app.ServiceName).service"
$app.ServiceFileContent = 
"[Unit]
Description=$ServiceName
Requires=network.target
After=dhcpcd.service

[Service]
ExecStart=/opt/$ServiceName/$ExeName
Restart=on-failure
Type=simple

[Install]
WantedBy=multi-user.target
"

##
## Action
##

if (!$SkipPublish) {
    run {dotnet publish  -r 'linux-x64' $ProjectName -o $localAppRoot}# --configuration Release .}# /property:AssemblyName="$ServiceName"}
    #Move-Item -Force "$localAppRoot/$exeName" "$localAppRoot/$ServiceName"
}

if (!(Test-Path $localAppRoot) -or (Get-ChildItem $localAppRoot).Length -eq 0) {throw "No files to upload."}

#### Create a Linux service
Invoke-Command `
    -HostName $app.HostName `
    -UserName $app.UserName `
    -ArgumentList $app, $function:run `
    -ScriptBlock {
        param($app, $runFunc)
        $ErrorActionPreference = 'Stop'
        #$run = [scriptblock]::Create($runFunc)

        $restart = $false
        if (Get-Process -Name $app.ExeName -ErrorAction SilentlyContinue) {
            sudo systemctl stop $app.ServiceName
            $restart = $true
        }

        ## delete the app folder
        if (!$app.DestAppRoot) {throw 'DestAppRoot is null'}
        sudo rm -rf $app.DestAppRoot

        ## test interruption on error
        #sudo mkdir '/does/not/exist/'

        ## re-create the app folder
        sudo mkdir --parents $app.DestAppRoot
        sudo chown $app.UserName $app.DestAppRoot

        ## create a service file
        $servicePath = "/etc/systemd/system/$($app.ServiceName).service"
        sudo sh -c "echo '$($app.ServiceFileContent)' > '$servicePath'"
    }

#### Copy the app
run {scp -P $Port -r "$localAppRoot/*" "$UserHost`:$($app.DestAppRoot)" | out-null}

#### Revert system permissions
Invoke-Command `
    -HostName $app.HostName `
    -UserName $app.UserName `
    -ArgumentList $app `
    -ScriptBlock {
        param($app)
        sudo chown -R "root" $app.DestAppRoot
        sudo chmod +x (Join-Path $app.DestAppRoot $app.ExeName)

        ## File changed on disk. Run 'systemctl daemon-reload' to reload units.
        sudo systemctl daemon-reload

        if ($restart) {
            sudo systemctl start $app.ServiceName
        }
    }

# $ses = New-PSSession -HostName $app.HostName -UserName $app.UserName
# try {
#     Invoke-Command $ses
#     . . .
# }
# finally {
#     Remove-PSSession $ses
# }
