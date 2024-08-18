GameDetector is a powershell script for Playnite laucher that can detect your DRM Free games on varius source paths (user specify) in local or network paths copy it on your local disk of choise using free program Teracopy to take advantage of it's functions to ingore/retry/pause/que multiple copies and much more.

<b>GameDetector</b> is simple messagebox script that ask you what to do on every situation, also  required to presetup in script the install distination of choise.</br>
<b>GameDetectorGUI</b> provides you with UI interface that let you choose distination drive calculate the size of the game needed and also have the ability to free up space.

<h3><b>Installation:</b></h3>

Create a folder on desktop with name "GameDetector" copy all files in it (AddUpdateGameDetector.ps1, GameDetector.ps1, GameDetectorGUI.ps1).

Now create a text file in same folder with name "gamesources.txt" and add the paths that you store your games, local or network path one per line
example:

\\\192.168.0.10\games1\GAMES</br>
L:\GAMES

Files are ready, now you need to configure Playnite, in order to add script on right-click menu on every custom game easily goto <b>Settings (F4) > Scrips > Scripts</b> that run before game starts and add this 2 lines of script, this will make sure that add or update two options on every Custom game's right-click menu GameDetector and GameDetectorGUI:

$desktopPath = [Environment]::GetFolderPath("Desktop")</br>
. "$desktopPath\GameDetector\AddUpdateGameDetector.ps1"

Every time you launch any game the script above will <b>add</b> or <b>update</b> the options on every Custom (user added) game, there is an option to disable any or both options from right click menu by editing the two first lines in "AddUpdateGameDetector.ps1" script and set from $true to $false:
<p>
$enableGameDetector = $true</br>
$enableGameDetectorGUI = $true
</p>

</br>
Notice that every custom game needs to have root game folder as installation path example: </br>D:\Games\MyGame and not </br>D:\Games\MyGame\Bin\x64
