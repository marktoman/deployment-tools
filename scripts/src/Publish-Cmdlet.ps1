param(
    [Parameter()]
        [string] $ModuleManifest,
    [Parameter()]
        [string] $Project,
    [Parameter()]
        [string] $ModuleDirectoy
)

$ErrorActionPreference = 'Stop'

if (!$Project) {
    $csproj = Get-Item "./*.csproj"
    if ($csproj.Count -eq 0) {throw 'No project file'}
    if ($csproj.Count -gt 1) {throw 'Multiple project files'}
    $Project = $csproj.Path
}
if (!(Test-Path $Project)) {throw "Project does not exist at $Project"}

if (!$ModuleManifest) {
    $baseName = [IO.Path]::GetFileNameWithoutExtension($Project)
    $ModuleManifest = "./$baseName.psd1"
}
elseif ((Resolve-Path $ModuleManifest).Count -ne 1) {throw 'ModuleManifest resolved to multiple files'}

if (!(Test-Path $ModuleManifest)) {throw "Manifest does not exist at $ModuleManifest"}

if (!$ModuleDirectoy) {
    $modulePaths = $env:PSModulePath -split ';'
    if ($modulePaths.Count -lt 1) {throw 'The PSModulePath environment variable is empty'}
    $ModuleDirectoy = $modulePaths[0]
}

function UpdateManifest {

    $manifestValues = Get-Content -Raw $ModuleManifest | Invoke-Expression

    $oldVer = [version] $manifestValues.ModuleVersion
    $version = [version]::new($oldVer.Major, $oldVer.Minor, $oldVer.Build + 1)
    $manifestValues.ModuleVersion = [string] $version
    $manifestValues.PrivateData = @{} # PS Bug, doesn't create a proper hashtable otherwise

    Copy-Item $ModuleManifest $env:TEMP -Force
    New-ModuleManifest -Path $ModuleManifest @manifestValues

    return $version
}

function BuildAndDeploy([string] $version) {

    $projXml = [xml] (Get-Content -Raw $Project)
    if ($projXml.Project.PropertyGroup.CopyLocalLockFileAssemblies -ne 'true') {throw 'CopyLocalLockFileAssemblies is missing in the project. Dependencies would not be deployed.'}

    #TODO: Test if the psd1 file is set to 'copy to output' in the project file

    $moduleName = [IO.Path]::GetFileNameWithoutExtension($ModuleManifest)
    $outPath = [IO.Path]::Combine($ModuleDirectoy, $moduleName, $version)

    New-Item -ItemType Directory $outPath | Out-Null

    dotnet build $Project `
        -c Debug `
        -v m `
        -nologo `
        -o $outPath

    $deployedManifest = [IO.Path]::Combine($outPath, "$moduleName.psd1")
    if (!(Test-Path $deployedManifest)) {throw "Manifest has not been deployed. Make sure it's set to copy on build."}
}


$ver = UpdateManifest

BuildAndDeploy $ver
