import UIKit

class KeyboardViewController: UIInputViewController {

    @IBOutlet var nextKeyboardButton: UIButton!
    @IBOutlet var crashButton: UIButton!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        Bugsnag.startBugsnagWithApiKey("YOUR-API-KEY")
    }

    required override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        Bugsnag.startBugsnagWithApiKey("YOUR-API-KEY")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    
        // Perform custom UI setup here
        self.nextKeyboardButton = UIButton(type: .System)
    
        self.nextKeyboardButton.setTitle(NSLocalizedString("Next Keyboard", comment: "Title for 'Next Keyboard' button"), forState: .Normal)
        self.nextKeyboardButton.sizeToFit()
        self.nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
    
        self.nextKeyboardButton.addTarget(self, action: #selector(advanceToNextInputMode), forControlEvents: .TouchUpInside)
        
        self.view.addSubview(self.nextKeyboardButton)
    
        self.nextKeyboardButton.leftAnchor.constraintEqualToAnchor(self.view.leftAnchor).active = true
        self.nextKeyboardButton.bottomAnchor.constraintEqualToAnchor(self.view.bottomAnchor).active = true

        // Perform custom UI setup here
        self.crashButton = UIButton(type: .System)

        self.crashButton.setTitle(NSLocalizedString("Cause crash", comment: "Title for 'Crash' button"), forState: .Normal)
        self.crashButton.sizeToFit()
        self.crashButton.translatesAutoresizingMaskIntoConstraints = false

        self.crashButton.addTarget(self, action: #selector(crashStuff), forControlEvents: .TouchUpInside)

        self.view.addSubview(self.crashButton)

        self.crashButton.leftAnchor.constraintEqualToAnchor(self.nextKeyboardButton.rightAnchor).active = true
        self.crashButton.bottomAnchor.constraintEqualToAnchor(self.view.bottomAnchor).active = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated
    }

    override func textWillChange(textInput: UITextInput?) {
        // The app is about to change the document's contents. Perform any preparation here.
    }

    override func textDidChange(textInput: UITextInput?) {
        // The app has just changed the document's contents, the document context has been updated.
    
        var textColor: UIColor
        let proxy = self.textDocumentProxy
        if proxy.keyboardAppearance == UIKeyboardAppearance.Dark {
            textColor = UIColor.whiteColor()
        } else {
            textColor = UIColor.blackColor()
        }
        self.nextKeyboardButton.setTitleColor(textColor, forState: .Normal)
    }

    func crashStuff() {
        var list = [1,2,4]
        NSLog("item: %d", list[4])
    }
}
