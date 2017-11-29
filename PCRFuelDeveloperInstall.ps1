
$sep = "`n============"

echo '=================================================================='
echo "    Welcome to PCR Fuel Developer Install"
echo '=================================================================='
echo ''
start-sleep 1

# Steps.
# 1. Install Git4 win
# 2. Pull PSBabushka from dp185133 almgit repo
# 3. Pull NCR/PCR staging directory with PSBabushka scripts
# 4. Set execution policy
# 5. Start running the PSBabushka crapola!!

function Is-Installed( $program ) {
    $x86 = ((Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall") |
      Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } ).Length -gt 0;
    
    $x64 = ((Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") |
        Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } ).Length -gt 0;

    return $x86 -or $x64;
}


##################################################################
# Verify Git is installed and create shortcut function for this script
echo "$sep Checking for Git"
$psmodulepath = "$($env:USERPROFILE)\Documents\WindowsPowershell\Modules"
if (-not $(is-installed 'git version 2.14')) {
    echo "Installing Git"
    start-process .\Git-2.14.2.2-64-bit.exe -wait
} else {
    echo "Git 2.14 already installed"
}

$gitcmd = (get-command git).path

if (-not $gitcmd) { $gitcmd = "C:\program files\git\cmd\git.exe" } # -- default install location

function git { &$gitcmd $args }

git help > $null

if (-not $?) {
    echo "$sepGit did not install succesfully"
    start-sleep 5
    throw "Git did not install succesfully"
}


$fuelinstpath = $PWD

##################################################################
# Verify PS 3.0 or greater is installed
echo "$sep Checking for PowerShell 3.0 at least"

if ($PSVersionTable.psversion.major -lt 3) {
    echo "$sep Installing PowerShell 3"

    $tempexe = [System.IO.Path]::GetTempFileName() + ".msu"
    # https://download.microsoft.com/download/E/7/6/E76850B8-DA6E-4FF5-8CCE-A24FC513FD16/Windows6.0-KB2506146-x64.msu
    (new-object Net.WebClient).DownloadFile(
        "https://download.microsoft.com/download/E/7/6/E76850B8-DA6E-4FF5-8CCE-A24FC513FD16/Windows6.1-KB2506143-x64.msu",
        $tempexe)
    start-sleep 1.5
    start-process $tempexe -wait
    remove-item -force $tempexe

    read-host -prompt "$sep PowerShell updated; please re-run PCRFuelDeveloperInstall`nPress enter to finish..."
    throw "Powershell updated - need to restart"
}

##################################################################
# Verify PSBabushka is installed and module is in our working space
echo "$sep Checking for PSBabushka module"
$psmodulepath = "$($env:USERPROFILE)\Documents\WindowsPowershell\Modules"
if (-not $(test-path $psmodulepath\psbabushka)) {
    mkdir -force $psmodulepath
    cd $psmodulepath
    git clone http://almgit.ncr.com/scm/~dp185133/psbabushka.git
} else {
    echo "PSBabushka module already installed"
}


##################################################################
# Download PSBabushka Configuration files to a temp directory
$staging = "$($env:TEMP)\PCRFuelDeveloperInstall"
mkdir -force $staging

echo "$sep Downloading configuration files at $staging/PCRFuelBabushka"

if (-not $(test-path $staging/pcrfuelbabushka)) {
    echo "$sep Retrieving prerequisite definitions"
    pushd $staging
    git clone http://almgit.ncr.com/scm/~dp185133/pcrfuelbabushka.git
    popd
} else {
    echo "$sep Checking for new prerequisite definitions"
    pushd $staging\pcrfuelbabushka
    git pull http://almgit.ncr.com/scm/~dp185133/pcrfuelbabushka.git
    popd
}


echo "$sep Checking NCR/PCR Fuel Developer Prerequisites $sep Please assist in tools installation as needed."

##################################################################
# Invoke PSBabushka and watch the world burn
import-module psbabushka

$env:PATH_BABUSHKA = "$staging/pcrfuelbabushka"

try {
    invoke-psbabushka ncr-pcr-fuel-dev
} catch {
    echo "Error invoking PSBabushka to configure 'ncr-pcr-fuel-dev'."
}


echo "$sep PCR Fuel Developer Install is exiting; review output for errors."

read-host -prompt "Press enter to exit..."


