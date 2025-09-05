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
			openFile(lastFile)
		}
	}

	public func openFile(_ filename: String)
	{
		textField.tryLoadFile(filename)
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
		setTextField(to: newLines)
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
			setTextField(to: newLines)
		}
	}

	@IBAction func save(_ sender: AnyObject?) {
		if let fileName = textField.fileName {
			textField.string?.writeToFile(fileName, atomically: true, encoding: .UTF8StringEncoding, error: nil)
		}
	}


	@IBAction func gitToMarkdown(_ sender: AnyObject?) {
		processLines(convertGitLineToMarkdown)
		removeEmptySections(sender)
	}

	@IBAction func removeEmptySections(_ sender: AnyObject?) {
		let lines = textField.string?.componentsSeparatedByString("\n")
		let newLines = NSMutableArray()

		var headline: String? = nil
		var hasSpace: Boolean = false

		for l in lines {
			if l.hasPrefix("#") {
				headline = l
			} else if headline != nil && l == "" {
				hasSpace = true
			} else {
				if let h = headline {
					newLines.addObject(h)
					headline = nil
					if hasSpace {
						newLines.addObject("")
						hasSpace = false
					}
				}
				newLines.addObject(l)
			}
		}
		setTextField(to: newLines);
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

			var (issueID, l) = self.getIssueIDAndRemainderFromLine(line)

			l = l.stringByReplacingOccurrencesOfString("Hydrogene", withString: "C#", options: .CaseInsensitiveSearch, range: NSMakeRange(0, l.length))
			l = l.stringByReplacingOccurrencesOfString("Silver", withString: "Swift", options: .CaseInsensitiveSearch, range: NSMakeRange(0, l.length))
			l = l.stringByReplacingOccurrencesOfString("csC", withString: "Complete Class") // keep case sensitive

			l = l.stringByReplacingOccurrencesOfString("GoToDefinition", withString: "Go to Definition", options: .CaseInsensitiveSearch, range: NSMakeRange(0, l.length))
			l = l.stringByReplacingOccurrencesOfString("GTD", withString: "Go to Definition", options: .CaseInsensitiveSearch, range: NSMakeRange(0, l.length))

			if issueID != "0" {
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
				if !textA.hasPrefix("Merged") && textB.hasPrefix("Merged") {
					return .OrderedAscending
				} else if textA.hasPrefix("Merged") && !textB.hasPrefix("Merged") {
					return .OrderedDescending
				} else {
					return textA.lowercaseString.compare(textB.lowercaseString)
				}
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
				if !textA.hasPrefix("Merged") && textB.hasPrefix("Merged") {
					return .OrderedAscending
				} else if textA.hasPrefix("Merged") && !textB.hasPrefix("Merged") {
					return .OrderedDescending
				} else {
					return textA.lowercaseString.compare(textB.lowercaseString)
				}
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
		for i in 0 ..< len {
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

	private func getIssueIDAndRemainderFromLine(_ line: String) -> (String, String) {
		var issueID: String? = nil
		var l = line

		let extractIssueID = { (range: NSRange) in
			var potentialIssueID: NSString! = l.substringToIndex(range.location)
			var number = abs(potentialIssueID.intValue())
			if number > 0 || potentialIssueID == "0" {
				issueID = potentialIssueID
				l = l.substringFromIndex(range.location + 1).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet)
			} else {
				var trimmedPotentialIssueID = potentialIssueID.substring(fromIndex: 1)
				number = abs(trimmedPotentialIssueID.intValue())
				if number > 0 {
					issueID = potentialIssueID
					l = l.substringFromIndex(range.location + 1).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet)
				} else {
					issueID = nil
				}
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
		return (coalesce(issueID, "0"), l) // E486 Parameter 1 is "String?", should be "T1", in call to Tuple!.New<T1,T2>(_ aItem1: T1, _ aItem2: T2) -> Tuple2<T1,T2>!
		//return (issueID, l) // E486 Parameter 1 is "String?", should be "T1", in call to Tuple!.New<T1,T2>(_ aItem1: T1, _ aItem2: T2) -> Tuple2<T1,T2>!
							// E486 Parameter 2 is "String", should be "T2", in call to Tuple!.New<T1,T2>(_ aItem1: T1, _ aItem2: T2) -> Tuple2<T1,T2>!
	}

	private func getIssueIDFromLine(_ line: String) -> String {
		let (issueID, _) = getIssueIDAndRemainderFromLine(line)
		return issueID
	}

	private func getTextFromLine(_ line: String) -> String {
		let (_, text) = getIssueIDAndRemainderFromLine(line)
		return text
	}

	private func convertGitLineToMarkdown(_ line: String) -> String? {

		var l = line.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet)
		if l.length() == 0 || l.hasPrefix("#") || l.hasPrefix("*") {
			return line
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

		var issueID: String
		(issueID, l) = getIssueIDAndRemainderFromLine(l)

		if issueID == 0 {
			if l.length() == 0 || l.hasPrefix("Merge ") || l.hasPrefix("Squashed ") {
				return nil
			}
		}

		if issueID != "0" {
			return "* \(issueID): \(l)"
		} else {
			return "* \(l)"
		}
	}

	func setTextField(to newText: NSArray<String>) {
		//let oldText = textField.string

		//if let lUndoManager = textField.undoManager {
			//// Prepare the undo invocation target
			////let lUndoTarget = lUndoManager.prepare(invocationTarget: textField) as! NSTextView
			////lUndoTarget.string = oldText
			//lUndoManager.registerUndo(target: self, selector: #selector(restoreText(_:)), object: oldText)
			//lUndoManager.setActionName("Change Text")
		//}

		// Replace the text in the editor, which updates the NSTextField and the undo stack
		textField.string = newText.componentsJoinedByString("\n")
	}

	//@objc
	//func restoreText(_ oldText: String) {
		//let currentText = textField.string

		//if let lUndoManager = textField.undoManager {
			//lUndoManager.registerUndo(target: self, selector: #selector(restoreText(_:)), object: currentText)
			//lUndoManager.setActionName("Change Text")
		//}

		//textField.string = oldText
	//}

}