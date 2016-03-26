import Foundation

public protocol ITextViewDelegate {
	func textView(_ textView: TextView, loadedFile fileName: String)
	func textView(_ textView: TextView, gotNonFileText text: String)
}

public class TextView : NSTextView {
	
	var fileName: String?

	private func draggingEntered(sender: INSDraggingInfo) -> NSDragOperation {
		var pb = sender.draggingPasteboard
		var dragOperation: NSDragOperation! = sender.draggingSourceOperationMask()
		if pb.types?.containsObject(NSFilenamesPboardType) {
			if dragOperation & NSDragOperation.Copy != 0 {
				return .Copy
			}
		}
		if pb.types?.containsObject(NSPasteboardTypeString) {
			if dragOperation & NSDragOperation.Copy != 0 {
				return .Copy
			}
		}
		return .None
	}
	
	private func performDragOperation(sender: INSDraggingInfo) -> Bool {
		var pb = sender.draggingPasteboard()
		if pb.types?.containsObject(NSFilenamesPboardType) {
			var filenames: NSArray! = pb.propertyListForType(NSFilenamesPboardType)
			if filenames.count == 1 {
				tryLoadFile(filenames[0])
			}
		} else {
			if pb.types?.containsObject(NSPasteboardTypeString) {
				var draggedString: NSString! = pb.stringForType(NSPasteboardTypeString)
				setString(draggedString)
				fileName = nil
				if let delegate = delegate as? ITextViewDelegate {
					delegate.textView(self, gotNonFileText: draggedString)
				}
			}
		}
		return true
	}
	
	func tryLoadFile(fileName: String) {
		var error: NSError? = nil
		var fileContents = NSString.stringWithContentsOfFile(fileName, encoding: .UTF8StringEncoding, error: &error)
		if let error = error {
			// handle error
		} else {
			setString(fileContents)
			self.fileName = fileName
			if let delegate = delegate as? ITextViewDelegate {
				delegate.textView(self, loadedFile: fileName!)
			}
		}
	}

}
