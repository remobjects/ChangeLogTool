import AppKit

@NSApplicationMain @IBObject class AppDelegate : INSApplicationDelegate {

	var mainWindowController: MainWindowController?

	public func applicationDidFinishLaunching(_ notification: NSNotification!) {

		mainWindowController = MainWindowController()
		mainWindowController?.showWindow(nil)
	}

}