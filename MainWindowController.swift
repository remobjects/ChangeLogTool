import AppKit

@IBObject public class MainWindowController : NSWindowController, INSTextDelegate, ITextViewDelegate {

	init() {

		super.init(windowNibName: "MainWindow")

		// Custom initialization
	}

	public override func windowDidLoad() {

		super.windowDidLoad()

		// Implement this method to handle any initialization after your window controller's
		// window has been loaded from its nib file.
		textField.delegate = self
		updatetextView()

		if let lastFile = NSUserDefaults.standardUserDefaults.stringForKey(KEY_LAST_OPEN_FILE) {
			textField.tryLoadFile(lastFile)
		}
	}

	private func updatetextView()
	{
		textField.font = NSFont.fontWithName("Menlo",size:13);
		//textField.drawsBackground = false
		textField.textStorage?.font = textField.font


		/*let fieldEditor = window.fieldEditor(true, forObject: codeField)
		fieldEditor.setSelectedRange(NSMakeRange(0, 0))
		fieldEditor.setNeedsDisplay(true)
		fieldEditor.backgroundColor = codeField.backgroundColor*/
	}

	@IBOutlet var textField: TextView

	let KEY_LAST_OPEN_FILE = "LastOpenFile"

	func textView(_ textView: TextView, loadedFile fileName: String) {
		window?.title = "Change Log Tool — \(fileName.lastPathComponent)"
		NSUserDefaults.standardUserDefaults.setObject(fileName, forKey: KEY_LAST_OPEN_FILE)
	}

	func textView(_ textView: TextView, gotNonFileText text: String) {
		window?.title = "Change Log Tool"
		NSUserDefaults.standardUserDefaults.setObject(nil, forKey: KEY_LAST_OPEN_FILE)
	}

	func processLines(_ processor: (String) -> String) {
		let lines = textField.string?.componentsSeparatedByString("\n")
		let newLines = NSMutableArray()
		for l in lines {
			if let l2 = processor(l) {
				newLines.addObject(l2)
			}
		}
		textField.string = newLines.componentsJoinedByString("\n")
	}

	func processLinesInBlocks(_ processor: (NSArray) -> NSArray) {
		if let lines = textField.string?.componentsSeparatedByString("\n") {
			let newLines = NSMutableArray(capacity: lines.count)
			let currentBlock = NSMutableArray(capacity: lines.count)

			let processCurrentBlock = {
				if currentBlock.count > 0 {
					let processedBlock = processor(currentBlock)
					newLines.addObjectsFromArray(processedBlock)
					currentBlock.removeAllObjects()
				}
			}

			for l in lines {
				let l2 = l.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet)
				if !l2.hasPrefix("*") {
					processCurrentBlock()
					newLines.addObject(l)
				} else {
					currentBlock.addObject(l)
				}
			}
			processCurrentBlock()
			textField.string = newLines.componentsJoinedByString("\n")
		}
	}

	@IBAction func save(_ sender: AnyObject?) {
		if let fileName = textField.fileName {
			textField.string?.writeToFile(fileName, atomically: true, encoding: .UTF8StringEncoding, error: nil)
		}
	}


	@IBAction func gitToMarkdown(_ sender: AnyObject?) {
		processLines(convertGitLineToMarkdown)
	}

	@IBAction func sortByID(_ sender: AnyObject?) {
		processLinesInBlocks() { lines in
			return self.sortLinesByID(lines)
		}
	}

	@IBAction func sortByText(_ sender: AnyObject?) {
		processLinesInBlocks() { lines in
			return self.sortLinesByText(lines)
		}
	}

	@IBAction func cleanup(_ sender: AnyObject?) {
		processLines() { line in

			if line.length == 0 || line.hasPrefix("#") {
				return line
			}

			var issueID = 0
			var l: String
			(issueID, l) = self.getIssueIDAndRemainderFromLine(line)

			l = l.stringByReplacingOccurrencesOfString("Hydrogene", withString: "C#", options: .CaseInsensitiveSearch, range: NSMakeRange(0, l.length))
			l = l.stringByReplacingOccurrencesOfString("Silver", withString: "Swift", options: .CaseInsensitiveSearch, range: NSMakeRange(0, l.length))
			l = l.stringByReplacingOccurrencesOfString("csC", withString: "Complete Class") // keep case sensitive

			l = l.stringByReplacingOccurrencesOfString("GoToDefinition", withString: "Go to Definition", options: .CaseInsensitiveSearch, range: NSMakeRange(0, l.length))
			l = l.stringByReplacingOccurrencesOfString("GTD", withString: "Go to Definition", options: .CaseInsensitiveSearch, range: NSMakeRange(0, l.length))

			if issueID > 0 {
				return "* \(issueID): \(l)"
			} else {
				return "* \(l)"
			}
		}
	}

	//
	// Processing
	//

	func distinctArray(_ lines: NSArray) -> NSArray {
		return lines.valueForKeyPath("@distinctUnionOfObjects.self")!
	}

	func sortLinesByID(_ lines: NSArray) -> NSArray {
		return distinctArray(lines).sortedArrayUsingComparator() { a, b in
			let idA = self.getIssueIDFromLine(a)
			let idB = self.getIssueIDFromLine(b)
			if idA > idB {
				return .OrderedAscending
			} else if idA < idB {
				return .OrderedDescending
			} else {
				let textA = self.getTextFromLine(a)
				let textB = self.getTextFromLine(b)
				return textA.lowercaseString.compare(textB.lowercaseString)
			}
		}
	}

	func sortLinesByText(_ lines: NSArray) -> NSArray {
		return distinctArray(lines).sortedArrayUsingComparator() { a, b in
			let idA = self.getIssueIDFromLine(a)
			let idB = self.getIssueIDFromLine(b)
			let textA = self.getTextFromLine(a)
			let textB = self.getTextFromLine(b)
			if (idA == 0) == (idB == 0) {
				return textA.lowercaseString.compare(textB.lowercaseString)
			} else if idA == 0 {
				return .OrderedDescending
			} else {
				return .OrderedAscending
			}

		}
	}

	private func stringStartsWithGitRev(_ string: NSString!) -> Bool {
		let len = length(string)
		if len < 7 {
			return false
		}
		for var i: Int32 = 0; i < len; i++ {
			var c: unichar = string.characterAtIndex(i)
			if i > 0 && c == " " {
				return true
			}
			if !(c >= "a" && c <= "f" || c >= "A" && c <= "F" || c >= "0" && c <= "9") {
				return false
			}
		}
		return true
	}

	private func getIssueIDAndRemainderFromLine(_ line: String) -> (Int, String) {
		var issueID = 0
		var l = line

		let extractIssueID = { (range: NSRange) in
			var potentialIssueID: NSString! = l.substringToIndex(range.location)
			issueID = abs(potentialIssueID.intValue())
			if issueID > 0 || potentialIssueID == "0" {
				l = l.substringFromIndex(range.location + 1).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet)
			}
		}

		if l.hasPrefix("* ") {
			l = l.substringFromIndex(2)
		}
		var colon = l.rangeOfString(":")
		if colon.location != NSNotFound && colon.location > 0 && colon.location < 20 {
			extractIssueID(colon)
		} else {
			colon = l.rangeOfString(" ")
			if colon.location != NSNotFound && colon.location > 0 && colon.location < 20 {
				extractIssueID(colon)
			}
		}
		l = l.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet)
		return (issueID, l)
	}

	private func getIssueIDFromLine(_ line: String) -> Int {
		let (issueID, _) = getIssueIDAndRemainderFromLine(line)
		return issueID
	}

	private func getTextFromLine(_ line: String) -> String {
		let (_, text) = getIssueIDAndRemainderFromLine(line)
		return text
	}

	private func convertGitLineToMarkdown(_ line: String) -> String? {

		var l = line.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet)
		if l.length() == 0 {
			return nil
		}
		if l.hasPrefix("# ") {
			return line
		}
		if l.hasPrefix("* ") {
			l = l.substringFromIndex(2)
		}
		if stringStartsWithGitRev(l) {
			var dash = l.rangeOfString(" - ")
			if dash.location > 0 && dash.location <= 16 {
				l = l.substringFromIndex(dash.location + 3)

				var parens = l.rangeOfString("(", options: NSStringCompareOptions.BackwardsSearch)
				if parens.location > 0 && parens.location < l.length() {
					l = l.substringToIndex(parens.location)
					parens = l.rangeOfString("(", options: NSStringCompareOptions.BackwardsSearch)
					if parens.location > 0 && parens.location < l.length() {
						l = l.substringToIndex(parens.location)
					}
				}
			}
		}

		var issueID = 0
		(issueID, l) = getIssueIDAndRemainderFromLine(l)

		if issueID == 0 {
			if l.length() == 0 || l.hasPrefix("Merge ") || l.hasPrefix("Squashed ") {
				return nil
			}
		}

		if issueID > 0 {
			return "* \(issueID): \(l)"
		} else {
			return "* \(l)"
		}
	}
}