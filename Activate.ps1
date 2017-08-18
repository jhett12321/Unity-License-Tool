# Config
$licensesFile = "unityLicenses.csv";
$unityPath = "D:/Unity/Editor/Unity.exe";
$dummyLogTime = 5;
$dummyPostInitTime = 10;

$scriptPath = $MyInvocation.MyCommand.Path;
$dir = Split-Path $scriptPath;

cd $dir;

# HACK!!
# We first load Unity without activating due to an issue where activation will fail if we immediately start from the command line.
# This process is killed after we detect "Command Line Arguments" in the editor log, as this indicates Unity has loaded.
$dummyLogPath = "$pwd\dummy.log";
Remove-Item $dummyLogPath;
$dummyProc = Start-Process $unityPath -ArgumentList "-logFile `"$dummyLogPath`"" -NoNewWindow -PassThru;

$dummyLoaded = $false;
while(($dummyLoaded -eq $false))
{
    Start-Sleep -s $dummyLogTime;

    $dummyLogData = Get-Content $dummyLogPath;

    foreach ($line in $dummyLogData)
    {
        if($line -like "*COMMAND LINE ARGUMENTS*")
        {
			# Unity has initialized. Give it a bit more time to reach the license screen before terminating.
			Start-Sleep -s $dummyPostInitTime;
            $dummyLoaded = $true;
            break;
        }
    }
}

Stop-Process -InputObject $dummyProc;
Wait-Process -InputObject $dummyProc;

# Add our licenses to the available pool for elastic agents.
$licenseCSV = @(Import-Csv $licensesFile);

$availableLicenses = New-Object System.Collections.ArrayList;
$availableLicenses.AddRange($licenseCSV);

$activated = $false;

# Attempts to activate Unity using a license from the configured pool.
function Activate
{
    # Gets a random license, and removes it from our pool.
    $license = Get-Random $script:availableLicenses.ToArray();
    $script:availableLicenses.Remove($license);

    $username = $license.Username;
    $pass = $license.Password;
    $serial = $license.Serial;
    $logFile = "$pwd\activation.log";

    # Build our arguments with the selected license
    $unityArgs = "-quit -batchmode -serial $serial -username $username -password $pass -createProject `"c:\temp`" -logFile `"$logFile`"";
    
    # Attempt activation
    $process = Start-Process $unityPath -ArgumentList $unityArgs -NoNewWindow -PassThru -Wait;

    # Write activation log to screen.
    $logData = Get-Content $logFile;
    foreach ($line in $logData)
    {
        write-host $line;
    }

    # Update our activation status if we successfully activated.
    if(($process.ExitCode -eq 0))
    {
        $script:activated = $true;
    }
    else
    {
        Write-Host "License activation attempt failed. Re-attempting with new license from pool.";
    }
}

# Try activating Unity until we succeed, or run out of licenses.
while(($activated -eq $false) -and ($availableLicenses.Count -gt 0))
{
    Activate;
}

if(($activated -eq $false))
{
    Write-Host "License activation failed. There are no more available licenses in pool."
    Exit 1;
}

else
{
    Write-Host "Unity activation succeeded. Exiting..."
    Exit 0;
}