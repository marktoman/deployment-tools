
## Publish-Cmdlet.ps1

Builds and deploys the project as a versioned PS module. The build version is automatically incremented. The project is validated to be set to copy all assemblies on build. Powershell Core only.


### Usage
```powershell
Publish-Cmdlet.ps1 [[-ModuleManifest] <string>] [[-Project] <string>] [[-ModuleDirectoy] <string>]
```

#### -ModuleManifest
Path to the psd1 manifest file. If ommited, it searches the current directory.

#### -Project
Path to the csproj file. If ommited, it searches the current directory.

#### -ModuleDirectoy
Path to the deployment directory. If ommited, it uses the first path in `$env:PSModulePath`.

