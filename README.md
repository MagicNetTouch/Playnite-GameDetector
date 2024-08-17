GameDetector is a powershell script for Playnite laucher that can detect your DRM Free games on varius source paths (user specify) in local or network paths copy it on your local disk of choise using free program Teracopy to take advantage of if functions to ingore/retry/pause/que multiple copies and much more.

GameDetector is simple messagebox script that ask you what to do on every situation, also  required to presetup in script the install distination of choise.
GameDetectorGUI provides you with UI interface that let you choose distination drive calculate the size of the game needed and also have the ability to free up space.

Installation:

Create a folder on desktop with name "GameDetector" copy all files in it (AddUpdateGameDetector.ps1, GameDetector.ps1, GameDetectorGUI.ps1).

Now create a text file in same folder with name "gamesources.txt" and add the paths that you store your games, local or network path one per line
example:
\\192.168.0.10\games1\GAMES
L:\GAMES

Files are ready now need to configure Playnite, in order to add script on right click menu on every game easily goto Settings (F4) > Scrips > Scripts that run before game starts and add this 2 lines of script, this will make sure that add or update 2 options on every Custom game's right click menu GameDetector and GameDetectorGUI:
$desktopPath = [Environment]::GetFolderPath("Desktop")
. "$desktopPath\GameDetector\AddUpdateGameDetector.ps1"

Every time you lunche any game this script above will add or update the options on every Custom (user added) game, there is option to disable any or both options from right click menu by editing the two first lines in "AddUpdateGameDetector.ps1" script and set from $true to $false:
$enableGameDetector = $true
$enableGameDetectorGUI = $true


Notice the every custom game need to have root game folder as installation path example: D:\Games\MyGame and not D:\Games\MyGame\Bin\x64
