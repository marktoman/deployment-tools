param(
    [Parameter(Mandatory)]
        [string] $ProjectFile
)
$ErrorActionPreference = 'Stop'

$nugetRepo = Get-Content -Raw ~/.devcfg/nuget-store.json | ConvertFrom-Json

#$verFile = "$PSScriptRoot\.$ProjectFile.version"
# $ver = [int[]] (Get-Content $verFile -EA 0 | ForEach-Object split .)
# if (!$ver) {$ver = 1,0,0} else {$ver[2]++}
# $verStr = $ver -join '.'
# Remove-Item $verFile -Force -EA 0
# $verStr | Out-File $verFile -Force
# Set-ItemProperty -Path $verFile -Name Attributes -Value 'Hidden'

$projFileXml = [xml](Get-Content $ProjectFile -Raw)
$prop = $projFileXml.Project.GetElementsByTagName('PropertyGroup')[0]
if ($prop.PackageVersion -eq $null) {
    $verEl = $prop.AppendChild($projFileXml.CreateElement('PackageVersion'))
    $ver = 0, 0, 1
}
else {
    $verEl = $prop.GetElementsByTagName('PackageVersion')[0]
    $ver = [int[]] $verEl.InnerText.Split('.')
    $ver[2]++
}
$verEl.InnerText = $ver -join '.'
$projFileXml.Save($ProjectFile)

#-p:PackageVersion=$verStr `
# msbuild $ProjectFile `
#     -p:Configuration=Debug `
#     -t:Pack `
#     -p:IncludeSymbols=true `
#     -v:m `
#     -p:OutputPath="D:\DATA\Dvlp\NuGet" `
#     -nologo `

dotnet pack $ProjectFile `
    -c Debug `
    --include-symbols `
    -v m `
    -nologo `
    -o $nugetRepo.path

# dotnet pack [<PROJECT>] /p:PackageVersion=1.2.3 [-c|--configuration] [--force] [--include-source] [--include-symbols] [--no-build] [--no-dependencies] [--no-restore] [-o|--output] [--runtime] [-s|--serviceable] [-v|--verbosity] [--version-suffix]