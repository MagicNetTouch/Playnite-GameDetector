$enableGameDetector = $true
$enableGameDetectorGUI = $true

$actionName = "GameDetector"
$actionNameGUI = "GameDetector GUI"
$script = '# GameDetector
$desktopPath = [Environment]::GetFolderPath("Desktop")
. "$desktopPath\GameDetector\GameDetector.ps1"'
$scriptGUI = '# GameDetectorGUI
$desktopPath = [Environment]::GetFolderPath("Desktop")
. "$desktopPath\GameDetector\GameDetectorGUI.ps1"'

foreach ($gg in $PlayniteApi.Database.Games) {
	if ($gg.IsCustomGame) {
		$found = $false
		$foundGUI = $false
		$actionGameDetector = $null
		$actionGameDetectorGUI = $null
		
		foreach ($action in $gg.GameActions) {
			if ($action.Name -eq $actionName) {
				if ($enableGameDetector) {
					$action.Type = 3
					$action.Script = $script
					$action.IsPlayAction = $false
					$PlayniteApi.Database.Games.Update($gg)
				}
				$found = $true
				$actionGameDetector = $action
			}
			if ($action.Name -eq $actionNameGUI) {
				if ($enableGameDetector) {
					$action.Type = 3
					$action.Script = $scriptGUI
					$action.IsPlayAction = $false
					$PlayniteApi.Database.Games.Update($gg)
				}
				$foundGUI = $true
				$actionGameDetectorGUI = $action
			}
		}
		if (-not $found) {
			if ($enableGameDetector) {
				$gameAction = New-Object Playnite.SDK.Models.GameAction
				$gameAction.Name = $actionName
				$gameAction.Type = 3
				$gameAction.Script = $script
				$gameAction.IsPlayAction = $false
				
				$gg.GameActions.Add($gameAction)
				$PlayniteApi.Database.Games.Update($gg)
			}
		} else {
			if (-not $enableGameDetector) {
				#remove
				$gg.GameActions.Remove($actionGameDetector)
			}
		}
		if (-not $foundGUI) {
			if ($enableGameDetectorGUI) {
				$gameAction = New-Object Playnite.SDK.Models.GameAction
				$gameAction.Name = $actionNameGUI
				$gameAction.Type = 3
				$gameAction.Script = $scriptGUI
				$gameAction.IsPlayAction = $false
				
				$gg.GameActions.Add($gameAction)
				$PlayniteApi.Database.Games.Update($gg)
			}
		} else {
			if (-not $enableGameDetectorGUI) {
				#remove
				$gg.GameActions.Remove($actionGameDetectorGUI)
			}
		}
	}
}