
# Choco Powershell Module Remixer

Based on the choco remixer project on github from TheCakeIsNaOH.

Downloads powershell modules from the powershell gallery, create a choco package for installing the powershell module (based on a choco template) and pack it for internal use.


## Prerequisites

## Create the powershell-module template

Create the template package with: `choco pack running in the psmodule-template directory`

Install the template package with: `choco install .\powershell-module.template.x.y.z.nupkg -y`

Verify the installation with: `choco template list`

### How to use the template manually

Use template for creating the skeleton with:
`choco new --Name=test.powershell --template powershell-module PackageVersion=1.0.0 ModuleName=test`

Copy the zipped powershell module (test.zip for above example) in the above created "tools" folder.

Use choco pack for packaging the module.

### Package Parameters

The created choco packages have the following parameters:

You can pass the following parameters for packages created with this template:

* `/core`     - Installs the module in the AllUsers scope for PowerShell Core;
* `/desktop`  - Installs the module in the AllUsers scope for Windows PowerShell (ie. Desktop Edition);

You can pass both `/core` and `/desktop` parameters to install on both. If you pass no parameters then `/desktop` is assumed.



## Usage of the Powershell Module Remixer

1. Setup the configuration config.xml based on the config.xml.template.

2. Setup the wanted powershell modules (download.xml) based on the download.xml.template (pspkg instead of pkg)

3. Download with `Invoke-DownloadPSModulePkg`

4. Internalize with `Invoke-InteralizsePSModulePkg`


















## What is this?

This automates some tasks involved in maintaining a private Chocolatey repository, specifically focusing on repositories hosted on Nexus.

- Checking for packages that out of date in a Nexus nuget repository, and updating them.

- Moving packages from a Nexus proxy repository to a hosted Nexus repository.

- [Internalizing/Recompiling](https://chocolatey.org/docs/how-to-recompile-packages) select Chocolatey packages, otherwise known as embedding the binaries inside the package.

## Requirements

- PowerShell v5.1+ - Primarily used so far on Windows, should work fine with Linux, but I have not thoroughly tested it yet.
- `choco` installed and on your path
- A nuget repository or a folder with `.nupkg`s to internalize. Nexus is the repository that I use and test with.
	- Drop path's are available with ProGet only
	- RepoMove and RepoSearch are Nexus only

## Setup

- Clone this repository
- Chocolatey is required, make sure that it is installed and working properly.
- Copy `*.xml.template` files to `*.xml` and edit them.
    - See the files for comments about each of the options.
- The path to each of these files can be specified as such (in order of precedence):
    1. Manually with the `-configXML`, `-internalizedXML`, and `-repoCheckXML` arguments to the locations of these files.
    2. Manually with the `-folderXML` argument which specifies the location to a folder with all three files.
    3. Then if neither of those is specified, the folder that contains the `choco-remixer.psm1` module will be checked.
    4. Then the parent folder of the module will be checked.
    5. Finally, the `$env:AppData\choco-remixer` folder will be checked (`$env:HOME/config/choco-remixer` on Linux)
- If you are using the automatic pushing (`pushPkgs`), make sure `choco` has the appropriate `apikey` setup for that URL.
- It is a good idea to put the xml files in a git repository.

## Operation

- Import the `choco-remixer` PowerShell module
- Run `Invoke-InternalizeChocoPkg`

- If you have `useDropPath` and `pushPkgs` disabled, the internalized packages are located inside the specified `workDir`.
- If you have `writePerPkgs` disabled, add the package versions to `internalized.xml` under the correct IDs. Otherwise, it will try to internalize them again.

- If continuously re-running for development or bug fixing, use the `-skipRepoCheck` switch, so as to not get rate limited by chocolatey.org

## Adding support for more packages

See [ADDING_PACKAGES.md (in progress)](https://github.com/TheCakeIsNaOH/choco-remixer/blob/master/ADDING_PACKAGES.md) for more information on how to add support for another package. PRs welcome, see [CONTRIBUTING.md](https://github.com/TheCakeIsNaOH/choco-remixer/blob/master/CONTRIBUTING.md) for more information

Otherwise, open an [issue](https://github.com/TheCakeIsNaOH/choco-remixer/issues/new) to see if I am willing to add support.


## Why have internalization functionality?

- Because relying on software to be available at a specific URL on the internet in perpetuity is not a good idea for a number of reasons.
- Manually downloading and internalizing for each individual package version is huge amount of work for any quantity of packages.
- Allows (most) packages to work on offline/air gapped environments.
- Makes install a previous version always possible. Some software vendors only have their latest version available to download, in which case old package versions break.

## Why this is better than the Chocolatey official internalizer

In comparison with the [Chocolatey business license](https://chocolatey.org/pricing#faq-pricing) that has [automated internalization functionality](https://chocolatey.org/docs/features-automatically-recompile-packages), choco-remixer:

- Is free and open source software
- Is available at no cost, instead of starting at $1,600/year, which is out of reach for almost all non-business users.
- Does not require a licensed Chocolatey installation to install the internalized packages.
- Validates checksums of all downloaded binaries (`.nupkg`s included), or warns if checksums are not available.
- Is available for Linux systems.

## Caveats

- I am still actively developing this, I make no promises that it is %100 stable.
- Packages are supported by whitelist, and support must be added individually for each package.

## Immediate TODOs

- Add license to files
- Add support for internalizing package icons
- Comment based help for all public functions, specifically in Edit-InstallChocolateyPackage (platyps?)
- Module metadata creation, module install, other helper scripts
- Switch so invoke-internalizechocopkg can be run with a single chocolatey package

## Long term TODOs

- Module improvements, chocolatey package, powershell gallery?
- Async/Parallelize file searching, copying, packing, possibly downloading
- Ability to bump version of nupkg (fix version)
- Add option to trust names of nupkg's in searching, allows for quicker search
- Git integration for personal-packages.xml
- Multiple personal-packages.xml files (for now it probably is best to add an alias to your profile for each xml)
- Add capability to directly specify package internalization from xml with a separate function
- Pester, other testing?
- Drop dependency on `choco.exe`, use `chocolatey.lib` after upgrade to dotnet core

## Continuous TODOs

- Better verbose/debug and other information output
- generalize more functionality and make available as functions.
- Move more packages to no custom function, use generic functions
