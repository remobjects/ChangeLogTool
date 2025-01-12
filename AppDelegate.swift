import AppKit
import RemObjects.Elements.RTL

@NSApplicationMain @IBObject class AppDelegate : INSApplicationDelegate {

	var mainWindowController: MainWindowController?

	override func applicationDidFinishLaunching(_ notification: NSNotification!) {

		mainWindowController = MainWindowController()
		mainWindowController?.showWindow(nil)

		writeLn("Environment.DesktopFolder \(Environment.DesktopFolder)")
		var files = Folder.GetFiles(Environment.DesktopFolder)
						.Where({ $0.PathExtension == ".txt" })
						.Where({ $0.LastPathComponent.StartsWith("elements-") || $0.LastPathComponent.StartsWith("rofx-") || $0.LastPathComponent.StartsWith("hydra-") })
						.OrderByDescending({ File.DateModified($0) }).ToList()
		writeLn("files \(files)")
		if files.Count() > 0 {
			mainWindowController?.openFile(files.First());
		}
	}

	@IBAction func showMainWindow(_ sender: AnyObject?) {
		mainWindowController?.showWindow(nil)
	}

	override func applicationDidBecomeActive(_ notification: Notification!) {
		//if _notFirstLaunch {
			//showWelcomeIfNeeded()
		//}
		//_notFirstLaunch = true
		//SBLSearchManager.sharedInstance.updateFromPasteBoardIfNeeded()
		mainWindowController?.showWindow(nil)
	}

}