Add-Type -AssemblyName PresentationCore,PresentationFramework
$dirDistination = "g:\Games"
$teracopypath = "C:\Program Files\TeraCopy\TeraCopy.exe"
$playpath = ""
$file = ""
[bool] $found = 0
$desktopPath = [Environment]::GetFolderPath("Desktop")
$folderName = $Game.InstallDirectory.Split("\")[-1]
$orgDirSource = $Game.InstallDirectory
$installDirParts = $orgDirSource.Split("\")

if ($installDirParts.Count -gt 2) {
	if ($orgDirSource.StartsWith("\\")){
		$DestSemiPath = $installDirParts[3..($installDirParts.count-2)] -join "\"
	} else {
		$DestSemiPath = $installDirParts[1..($installDirParts.count-2)] -join "\"
	}
} else {
	$DestSemiPath = ""
}

$GamePaths = $desktopPath + "\GameDetector\gamesources.txt"
$SourcesLookup = Get-Content -Path $GamePaths
$driveletter = $dirDistination.SubString(0,2)

function FormatBytes($num) 
{
    $suffix = "B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"
    $index = 0
    while ($num -gt 1kb) 
    {
        $num = $num / 1kb
        $index++
    } 

    "{0:N1} {1}" -f $num, $suffix[$index]
}

function IsNwp($path)
{
    $root = $path.SubString(0,1)

    # Check if root starts with "\\", clearly an UNC
    if ($path.StartsWith("\\")) {
        return $true
    }

    # Check if the drive is a network drive
    $x = new-object system.io.driveinfo($root)
    if ($x.drivetype -eq "Network"){
        return $true
    }

    return $false
}

$isNetPath = IsNwp("$orgDirSource")

# Find first play action
ForEach ($action in $Game.GameActions) {
	if($action.IsPlayAction){
		$playpath=$PlayniteApi.ExpandGameVariables($game, $action.Path)
		break
	}
}

# Check if it's Custom Game
if (!$Game.IsCustomGame) {
	[System.Windows.MessageBox]::Show("This only supports custome games.","Abort.",'Ok','Question')
	exit 1
} 
# Installed on local disk and exists also
if ($Game.IsInstalled -and !$isNetPath) {
	if (Test-Path -Path $playpath -PathType Leaf) {
		[System.Windows.MessageBox]::Show("Game already installed.","OK",'Ok','Question')
		exit 1
	}
}
# Installed on network disk/path
if ($Game.IsInstalled -and $isNetPath) {
	$Result = [System.Windows.MessageBox]::Show("Game is configured on Network Disk/Path!`n`nSelect:`n[Yes]: if you wish to copy game on local disk.`n[No]: if you wish to try start the game from current path.",$Game.Name,'YesNoCancel','Question')
	
	if ($Result -eq "No") {
		$DbId = $PlayniteApi.ExpandGameVariables($Game, "{DatabaseId}")
		$PlayniteApi.StartGame($DbId)
		exit 1
	}
	if ($Result -eq "Cancel") {
		exit 1
	}
}

# disks filter by connection
#gwmi win32_diskdrive | ?{$_.interfacetype -eq "USB" -or $_.interfacetype -eq "SCSI" -or $_.interfacetype -eq "IDE"} | %{gwmi -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID=`"$($_.DeviceID.replace('\','\\'))`"} WHERE AssocClass = Win32_DiskDriveToDiskPartition"} |  %{gwmi -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID=`"$($_.DeviceID)`"} WHERE AssocClass = Win32_LogicalDiskToPartition"} | %{$_.deviceid}

$disks = gwmi win32_diskdrive | %{gwmi -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID=`"$($_.DeviceID.replace('\','\\'))`"} WHERE AssocClass = Win32_DiskDriveToDiskPartition"} |  %{gwmi -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID=`"$($_.DeviceID)`"} WHERE AssocClass = Win32_LogicalDiskToPartition"} | %{$_.deviceid}

ForEach ($diskletter in $disks){
	$file = $playpath.replace($orgDirSource.Split("\")[0], $diskletter)
	if (Test-Path -Path $file -PathType Leaf) {
		# ask user to start the game
		$Result = [System.Windows.MessageBox]::Show("Game found on other local disk!`nDo you wish to update game info and start the game now?",$Game.Name,'OKCancel','Question')
		if ($Result -eq "OK") {
			# update game info
			$Game.InstallDirectory = $diskletter + $orgDirSource.substring(2)
			$Game.IsInstalled = 1
			$PlayniteApi.Database.Games.Update($Game)
			
			$DbId = $PlayniteApi.ExpandGameVariables($Game, "{DatabaseId}")
			$PlayniteApi.StartGame($DbId)
			exit 1
		}
	}
}

# Try to detect game in users source paths
ForEach ($source in $SourcesLookup) {
	$file = $playpath.replace($orgDirSource,$source + "\" + $folderName)
	# $Result = [System.Windows.MessageBox]::Show($file,$source,'Ok','Question')
	if (Test-Path -Path $file -PathType Leaf) {
		# Game detected!
		$found = 1
		
		# Show form with all local disks except original install disk with name and free space for user to select copy distination disk
		
		# Get game folder size
		$GamefolderSize = (gci -force "$source\$folderName" -Recurse -ErrorAction SilentlyContinue| measure Length -s).sum
		
		# Get destination disk free-space in bytes
		$disk = Get-WmiObject Win32_LogicalDisk -ComputerName localhost -Filter "DeviceID='$driveletter'" | Select-Object FreeSpace
		$FreeSpaceFormated = FormatBytes($disk.FreeSpace)
		$GamefolderSizeFormated = FormatBytes($GamefolderSize)
		
		$Result = [System.Windows.MessageBox]::Show("Source:`n"+$source + "\" + $folderName + " (" +$GamefolderSizeFormated+")`nDestination:`n"+$dirDistination + "\" + $folderName+"`n`nDisk ($driveletter) free space: " + $FreeSpaceFormated + "`nContinue with folder copy?","Game detected.",'OKCancel','Question')
		
		if ($Result -eq "OK") {
			if (Test-Path -Path $teracopypath -PathType Leaf) {
				Start-Process -FilePath $teracopypath -ArgumentList "Copy `"$source\$folderName`" `"$dirDistination`" /OverwriteOlder /Close" -Wait
				# update game info
				$Game.InstallDirectory = $dirDistination + "\" + $folderName
				$Game.IsInstalled = 1
				$PlayniteApi.Database.Games.Update($Game)
				# ask user to start the game
				$Result = [System.Windows.MessageBox]::Show("Copy finish!`nDo you wish to start the game now?",$Game.Name,'OKCancel','Question')
				if ($Result -eq "OK") {
					$DbId = $PlayniteApi.ExpandGameVariables($Game, "{DatabaseId}")
					$PlayniteApi.StartGame($DbId)
				}
			} else {
				[System.Windows.MessageBox]::Show("Teracopy not found in path:`n$teracopypath","Error",'Ok','Question')
			}
		}
		break
	}
}
if (!$found) {
	[System.Windows.MessageBox]::Show("Game not found in any of the following locations:`n$SourcesLookup","Not Found.",'Ok','Question')
}

