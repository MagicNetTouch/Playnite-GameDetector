Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type -AssemblyName PresentationCore,PresentationFramework

[System.Windows.Forms.Application]::EnableVisualStyles()

#Version 1.0 Release
$teracopypath = "C:\Program Files\TeraCopy\TeraCopy.exe"
$playpath = ""
$file = ""
$dirDistination = ""
$driveletter = ""
[bool] $found = 0
$desktopPath = [Environment]::GetFolderPath("Desktop")
$folderName = $Game.InstallDirectory.Split("\")[-1]
$orgDirSource = $Game.InstallDirectory
$installDirParts = $orgDirSource.Split("\")

if ($installDirParts.count -gt 2) {
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

function RefreshDiskList($LV)
{
	$LV.Items.Clear()
	$phycicaldisks = gwmi win32_diskdrive | %{gwmi -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID=`"$($_.DeviceID.replace('\','\\'))`"} WHERE AssocClass = Win32_DiskDriveToDiskPartition"} |  %{gwmi -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID=`"$($_.DeviceID)`"} WHERE AssocClass = Win32_LogicalDiskToPartition"} | %{$_.deviceid + " "+$_.volumename}
    ForEach ($disk in $phycicaldisks){
        $lvi = [System.Windows.Forms.ListViewItem]::new()
        $lvi.Text = $disk
        $driveletter = $disk.SubString(0,2)
        $disk = Get-WmiObject Win32_LogicalDisk -ComputerName localhost -Filter "DeviceID='$driveletter'" | Select-Object FreeSpace
        $FreeSpaceFormated = FormatBytes($disk.FreeSpace)
		if ($gameSizeRequired -le $disk.FreeSpace){
			$lvi.ForeColor  = 'green'
		} else {
			$lvi.ForeColor  = 'red'
		}
        $lvi.SubItems.Add($FreeSpaceFormated)
        $LV.Items.Add($lvi)
    }
	
	$LV.Items.item(0).Selected = $true
}

function FreeUpDiskSpace {
    param ( $selectedDisk )
    $currDriveletter = $selectedDisk.SubString(0,2)
    $newGameFolder = $currDriveletter + "\" + $DestSemiPath

    $formFRSP = New-Object System.Windows.Forms.Form
    $formFRSP.SuspendLayout()
    $formFRSP.AutoScaleDimensions =  New-Object System.Drawing.SizeF(96, 96)
    $formFRSP.AutoScaleMode  = [System.Windows.Forms.AutoScaleMode]::Dpi
    $formFRSP.Text = "Root folders in: " + $newGameFolder
    $formFRSP.Size = New-Object System.Drawing.Size(340,350)
	$formFRSP.MinimumSize = New-Object System.Drawing.Size(340,350)
    $formFRSP.StartPosition = 'CenterScreen'
	$formFRSP.Font = New-Object System.Drawing.Font("",12,[System.Drawing.FontStyle]::Regular)
	$formFRSP.Add_Shown({
		$formFRSP.Activate()
	})
	
	$currDisk = Get-WmiObject Win32_LogicalDisk -ComputerName localhost -Filter "DeviceID='$currDriveletter'" | Select-Object FreeSpace
	$currFreeSpaceFormated = FormatBytes($currDisk.FreeSpace)
	
	$label = New-Object System.Windows.Forms.Label
	$label.Location = New-Object System.Drawing.Point(9,1)
	$label.Size = New-Object System.Drawing.Size(320,19)
	$label.Text = 'Current disk free space: ' + $currFreeSpaceFormated
	$label.Font = New-Object System.Drawing.Font("",10,[System.Drawing.FontStyle]::Regular)
	$formFRSP.Controls.Add($label)
	
	$label2 = New-Object System.Windows.Forms.Label
	$label2.Location = New-Object System.Drawing.Point(9,19)
	$label2.Size = New-Object System.Drawing.Size(340,19)
	$label2.Text = 'Checked total size to freeUp: 0'
	$label2.Font = $label.Font
	$formFRSP.Controls.Add($label2)

    $removeSelected = New-Object System.Windows.Forms.Button
    $removeSelected.Location = New-Object System.Drawing.Point(55,($formFRSP.height-72))
    $removeSelected.Size = New-Object System.Drawing.Size(220,26)
    $removeSelected.Text = 'Remove Selected Folders'
    $removeSelected.Anchor = "Bottom,Left"
	$removeSelected.Enabled = $false
	$removeSelected.DialogResult = [System.Windows.Forms.DialogResult]::OK
	$removeSelected.Add_Click({
		$removeSelected.enabled=$false
        $removeSelected.Text = 'Cleanup...'
        [System.Windows.Forms.Application]::DoEvents()
        $listView2.CheckedItems | foreach {
			#remove Directory
			$dirToRemove = $newGameFolder + "\" + $_.text
			Remove-Item -LiteralPath $dirToRemove -Force -Recurse
			Write-Host "Delete folder: " $dirToRemove
			}
		$formFRSP.Close()
    })
    $formFRSP.Controls.Add($removeSelected)

    $listView2 = New-Object System.Windows.Forms.ListView
 	
    $listView2.View = 'Details'
	$listView2.Location = New-Object System.Drawing.Point(10,40)
    $listView2.Size = New-Object System.Drawing.Size(($formFRSP.Width-38),($formFRSP.height-120))
    $listView2.Name = "listView2"
    $listView2.LabelEdit = $false
    $listView2.HideSelection = $false
    $listView2.FullRowSelect = $True
    $listView2.MultiSelect = $true
    $listView2.Autosize = $true
    $listView2.Anchor = "Top,Bottom,Left,Right"
    $listView2.GridLines = $True
	$listView2.CheckBoxes = $true
	$listView2.add_ItemChecked({

			[double] $selectedSize = 0
			
			$listView2.CheckedItems | foreach { $selectedSize += [double]$_.tag }
            $formatedOut = FormatBytes($selectedSize)
			$formatedRequired = FormatBytes($gameSizeRequired - $currDisk.FreeSpace)
			
			#Write-Host $selectedSize
			if ($selectedSize -ne 0)
			{
				if (($gameSizeRequired - $currDisk.FreeSpace) -le $selectedSize){
					$label2.ForeColor  = 'green'
					$removeSelected.Enabled = $true
				} else {
					$label2.ForeColor  = 'red'
					$removeSelected.Enabled = $false
				}
				$label2.Text = "Checked folders size to freeup: [ " + $formatedOut + " / " + $formatedRequired + " ]"
			} else {
				$label2.ForeColor  = 'red'
				$removeSelected.Enabled = $false
                $label2.Text = "Checked folders size to freeup: [ 0 B / " + $formatedRequired + " ]"
            }
	})

    $listView2.Columns.Add('Root Folders')
    $listView2.Columns.Add('Folder size')

    #$listView2.ShowCheckBoxes=$true

    if ($dpiKoef -gt 1){
        #$listview2.Font =  $Font
    }

    $formFRSP.Controls.Add($listView2)

    $formFRSP.Topmost = $true
	$formFRSP.ResumeLayout()

	$listView2.BeginUpdate()
	
	# get an array of subfolder full names in the $rootFolder

	$subfolders = (Get-ChildItem -Path $newGameFolder -Directory -Force -ErrorAction SilentlyContinue | Select-Object FullName).FullName

	foreach ($folder in $subfolders)  {
		$lvi = [System.Windows.Forms.ListViewItem]::new()
		$lvi.Text = Split-Path -Path $folder -Leaf
		
		$folderSize = (gci -force $folder -Recurse -ErrorAction SilentlyContinue| measure Length -s).sum
		$lvi.Tag = $folderSize
		#$lvi.Checked = $true
		$FreeSpaceFormated = FormatBytes($folderSize)
		$lvi.SubItems.Add($FreeSpaceFormated)
		
		$listView2.Items.Add($lvi)
	}

    $listView2.EndUpdate()
	$freeupBtn.Text = 'Free Disk Space'
	
	$listView2.AutoResizeColumns(0)
    $listView2.AutoResizeColumns(1)
    $result = $formFRSP.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::Cancel) {
		return "canceled"
	}
}

$waitCopy = $true

function ChooseDest ( $pathGameFound, $gameSizeRequired ) {
    $form = New-Object System.Windows.Forms.Form

    $form.SuspendLayout()
	$form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
    $form.AutoScaleMode  = [System.Windows.Forms.AutoScaleMode]::Dpi

    $form.Text = 'Choose installation disk'
    $form.Size = New-Object System.Drawing.Size(340,310)
    $form.StartPosition = 'CenterScreen'
    $form.MinimumSize = New-Object System.Drawing.Size(385,310)
	$form.Font = New-Object System.Drawing.Font("",12,[System.Drawing.FontStyle]::Regular)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(35,($form.height-73))
    $okButton.Size = New-Object System.Drawing.Size(70,26)
    $okButton.Text = 'OK'
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $okButton.Anchor = "Bottom,Left"
	$okButton.Enabled = $false
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(($okButton.Location.X+77),($okButton.Location.Y))
    $cancelButton.Size = New-Object System.Drawing.Size(75,$okButton.Size.Height)
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cancelButton.Anchor = "Bottom,Left"
    $form.CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)

    $freeupBtn = New-Object System.Windows.Forms.Button
    $freeupBtn.Location = New-Object System.Drawing.Point(($okButton.Location.X+160),($okButton.Location.Y))
    $freeupBtn.Size = New-Object System.Drawing.Size(140,$okButton.Size.Height)
    $freeupBtn.Text = 'Free Disk Space'
    $freeupBtn.Anchor = "Bottom,Left,Right"
    $form.Controls.Add($freeupBtn)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,5)
    $label.Size = New-Object System.Drawing.Size(360,33)
	$label.Anchor = "Top,Left,Right"
	$FormatedgameSizeRequired = FormatBytes($gameSizeRequired)
    #$label.Text = 'Choose disk to copy the game with at least [ ' + $FormatedgameSizeRequired + ' ] of free space:'
	$label.Text = "Source location: $pathGameFound [ $FormatedgameSizeRequired ]"
	$label.Font = New-Object System.Drawing.Font("",10,[System.Drawing.FontStyle]::Regular)
    $form.Controls.Add($label)

	$chkWaitCopy = New-Object System.Windows.Forms.CheckBox
	$chkWaitCopy.Location = New-Object System.Drawing.Point(10,($form.height-111))
	$chkWaitCopy.Text = 'Wait for copy to finish and update installation information ( Playnite UI freezes until copy finish )'
	$chkWaitCopy.Font = New-Object System.Drawing.Font("",10,[System.Drawing.FontStyle]::Regular)
	$chkWaitCopy.Size = New-Object System.Drawing.Size(($form.width-20),32)
	$chkWaitCopy.Checked = $true
	$chkWaitCopy.Anchor = "Bottom,Left,Right"
	$chkWaitCopy.Add_CheckStateChanged({
		if ($chkWaitCopy.Checked) {
			$global:waitCopy = $true
		}
		else {
			$global:waitCopy = $false
		}
	})
	$form.Controls.Add($chkWaitCopy)
	
    $listView1 = New-Object System.Windows.Forms.ListView
 
    $listView1.View = 'Details'
	$listView1.Location = New-Object System.Drawing.Point(10,40)
    $listView1.Size = New-Object System.Drawing.Size(($form.width-38),($form.height-157))
    $listView1.Name = "listView1"
    $listView1.LabelEdit = $false
    $listView1.HideSelection = $false
    $listView1.FullRowSelect = $True
    $listView1.MultiSelect = $false
    $listView1.Autosize = $true
    $listView1.Anchor = "Top,Bottom,Left,Right"
    $listView1.GridLines = $True

    $listView1.Columns.Add('Disk')
    $listView1.Columns.Add('Free Space',-2)
	$listView1.Add_SelectedIndexChanged({
		$x = $listView1.SelectedItems | foreach {$_.text}
		if ($x) {
			$driveletter = $x.SubString(0,2)
			$disk = Get-WmiObject Win32_LogicalDisk -ComputerName localhost -Filter "DeviceID='$driveletter'" | Select-Object FreeSpace
			if ($gameSizeRequired -le $disk.FreeSpace){
				$freeupBtn.Enabled = $false
				$okButton.Enabled = $true
			} else {
				$freeupBtn.Enabled = $true
				$okButton.Enabled = $false
			}
		}
	})
	
    # add destination paths and calc free disk space
	RefreshDiskList($listView1)
	
    $Form.Controls.add($listView1)
		
    $form.Topmost = $true
    $form.ResumeLayout()

    if ($dpiKoef -gt 1){
        #$listview1.Font =  $Font
    }

    #$listView1.Columns[0].width = 635
    $listView1.AutoResizeColumns(0)
	$listView1.AutoResizeColumns(1)
	
    $freeupBtn.Add_Click({
        $freeupBtn.Text = 'Caculating...'
        [System.Windows.Forms.Application]::DoEvents()
        $x = $listView1.SelectedItems | foreach {$_.text} 
        $fResult = FreeUpDiskSpace($x)
		$fResult = $fResult[-1]
		if ($fResult -eq "canceled") {
			Write-Host "Canceled."
			RefreshDiskList($listView1)
		} else {
			$okButton.Enabled = $true
			$okButton.PerformClick()
		}
    })

	$result = $form.ShowDialog()
	
	if ($result -eq [System.Windows.Forms.DialogResult]::OK)
	{	
		$x = $listView1.SelectedItems | foreach {$_.text}
		return $x
	} else {
		return 0
	}
}

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
		
		# Get game folder size in bytes
		$GamefolderSize = (gci -force "$source\$folderName" -Recurse -ErrorAction SilentlyContinue| measure Length -s).sum

		$result = ChooseDest "$source\$folderName" $GamefolderSize
		$result = $result[-1]

		if ($result -ne 0) {
			#Selected Drive Letter
			$selectedDrive = $result.SubString(0,2)
			$dirDistination = $selectedDrive + "\" + $DestSemiPath
			
			if (Test-Path -Path $teracopypath -PathType Leaf) {
				if ($waitCopy) {
					Start-Process -FilePath $teracopypath -ArgumentList "Copy `"$source\$folderName`" `"$dirDistination`" /OverwriteOlder /Close" -Wait
					
					# update game info
					$Game.InstallDirectory = $dirDistination + "\" + $folderName
					$Game.IsInstalled = 1
					$PlayniteApi.Database.Games.Update($Game)
				
					# ask user to start the game
					$qResult = [System.Windows.MessageBox]::Show("Copy finish!`nDo you wish to start the game now?",$Game.Name,'OKCancel','Question')
					if ($qResult -eq "OK") {
						$DbId = $PlayniteApi.ExpandGameVariables($Game, "{DatabaseId}")
						$PlayniteApi.StartGame($DbId)
					}
				} else {
					Start-Process -FilePath $teracopypath -ArgumentList "Copy `"$source\$folderName`" `"$dirDistination`" /OverwriteOlder /Close"
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

