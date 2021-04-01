
$sep = "`n============"

echo '=================================================================='
echo "    Welcome to CFR Fuel Developer Install"
echo '=================================================================='
echo ''
start-sleep 1


# Steps.
# 1a. Ensure we have PowerShell 3
# 1b. Install Git4 win
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
# Verify PS 3.0 or greater is installed
echo "$sep Checking for PowerShell 3.0 at least"

if ($PSVersionTable.psversion.major -lt 3) {

    # If you do not have .net 4 installed, you will get the message "update is not applicable to this PC" from powershell installer.
    # in this case install dotnet 4.7 via
    if (-not (test-path "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\")) {
        echo "DotNet 4 framework not found; Please install .NET 4.7..."
        start-process "https://download.microsoft.com/download/D/D/3/DD35CC25-6E9C-484B-A746-C5BE0C923290/NDP47-KB3186497-x86-x64-AllOS-ENU.exe"
        start-sleep 10
        throw "need to install .NET 4 framework; please re-run after installer completes"
    }
    
    
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
# Verify Git Is Installed and create shortcut function for this script.
# This is included with the installer because the main download is on
# amazonaws and gives a permission denied to invoke-webrequest.
echo "$sep Checking for Git"
if (-not $(is-installed 'git version 2.30')) {
    echo "Installing Git"
    $tempexe = [System.IO.Path]::GetTempFileName() + ".exe"
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12    
    invoke-webrequest -outfile $tempexe "https://github.com/git-for-windows/git/releases/download/v2.30.0.windows.2/Git-2.30.0.2-64-bit.exe"
    start-sleep 1.5
    start-process $tempexe -wait
    remove-item -force $tempexe
} else {
    echo "Git 2.30 already installed"
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
# Verify PSBabushka is installed and module is in our working space
echo "$sep Checking for PSBabushka module"
$psmodulepath = $env:psmodulepath -split ';' | select -first 1
if (-not $(test-path $psmodulepath\psbabushka)) {
    mkdir -force $psmodulepath
    cd $psmodulepath
    git clone https://almgit.ncr.com/scm/~dp185133/psbabushka.git
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
    git clone https://github.com/ncr-swt-cfr/pcrfuelbabushka.git
    popd
} else {
    echo "$sep Checking for new prerequisite definitions"
    pushd $staging\pcrfuelbabushka
    git pull https://github.com/ncr-swt-cfr/pcrfuelbabushka.git
    if ($?) {
        echo "$sep Prerequisite rules updated successfully"
    } else {
        echo "$sep Could not update prerequisite rules"
    }
    popd
}

function make-configuration( $name, $description, $configname ) {
    $config = [pscustomobject] @{ 'Name' = $name; 'Description' = $description; }
    Add-Member -MemberType ScriptMethod -name "getSymbolicConfigName" `
      -value ([scriptblock]::Create("`"$configname`"")) -inputObject $config
    $config
}


$selectedConfiguration = `
  (make-configuration 'Full Fuel Developer' 'All prerequisites for typical CFR Fuel Developer machine.' 'ncr-pcr-fuel-dev'),
  (make-configuration 'Only WEC7 Development' 'Prerequisites for only WEC7/Panther+x86 compilation environment.' 'ncr-pcr-wec7') |
  out-gridview -title "PCRFuelDeveloperInstall: Select Configuration" -outputmode single

#  (make-configuration 'WEC7 SDK Only' 'Only Install Panther/WEC7 SDK and patches.' 'panther-wec7-with-patches') |

if (-not $selectedConfiguration) {
    Write-Output "No configuration selected; exiting";
    throw "no configuration selected; nothing to do!"
}


. "$PSScriptRoot/Show-MessageBox.ps1"
$promptResponse = Show-MessageBox -title "Install $($selectedConfiguration.name) Tools?" -Msg `
  "Press 'Yes' to install all prerequisites automatically;`nPress 'No' to prompt before making changes for each prerequisite.`nPress 'Cancel' to abort." -YesNoCancel

if ($promptResponse -eq 'Cancel') { throw "Installation cancelled" }


echo "$sep Checking NCR/CFR Fuel Developer Prerequisites $sep Please assist in tools installation as needed."

##################################################################
# Invoke PSBabushka and watch the world burn
import-module psbabushka

$env:PATH_BABUSHKA = "$staging/pcrfuelbabushka"

$configName = $selectedConfiguration.getSymbolicConfigName()
try {
    if ($promptResponse -eq 'Yes') {
        invoke-psbabushka $configName
    } else {
        invoke-psbabushka $configName -confirm {
            param($name,$description,$block)
            $blockString = $block.ToString()
            $blockDesc = $blockString.Substring(0, [Math]::Min($blockString.length, 3200)) # only show max of about 80chars*40 linese
            $response = Show-MessageBox -Title "Install `"$name`"?" -YesNoCancel -Msg "Attempting to configure package `"$name`".`nActions to be performed:`n$blockDesc"
            if ($response -eq 'Cancel') {
                Write-Output "Aborting installation due to user cancel"
                throw "Install aborted!!"
            }
            ($response -eq 'Yes')
        }
    }
} catch {
    echo "Error invoking PSBabushka to configure '$($selectedConfiguration.Name)' ($configName)."
}


echo "$sep CFR Fuel Developer Install is exiting; review output for errors."

read-host -prompt "Press enter to exit..."


