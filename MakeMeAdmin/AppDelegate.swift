//
//  AppDelegate.swift
//  MakeMeAdmin
//
//  Created by Kett, Oliver on 20.01.15.
//  Copyright (c) 2015 Kett, Oliver. All rights reserved.
//

import Cocoa
import SystemConfiguration // for SCDynamicStoreCopyConsoleUser

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate { // we need NSTextFieldDelegate to override controlTextDidChange() for detecting changes to any of the NSTextField's
    // NSObject

    @IBOutlet weak var window: NSWindow!
    
    @IBOutlet weak var textFieldName: NSTextField!
    @IBOutlet weak var textFieldEMail: NSTextField!
    @IBOutlet weak var textFieldReason: NSTextField!
    @IBOutlet weak var textFieldComputerName: NSTextField!
    @IBOutlet weak var buttonSend: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    // open log from main menu
    @IBAction func showLogfile(sender: AnyObject) {
        if NSFileManager.defaultManager().fileExistsAtPath(Config.logFile) {
            NSTask.launchedTaskWithLaunchPath("/usr/bin/open", arguments: ["-a", "Console", Config.logFile])
        } else {
            showWarning("Es wurde noch keine Logdatei angelegt. Wahrscheinlich verwendest du MakeMeAdmin zum ersten mal.", buttonText: NSLocalizedString("Ok", comment: "aknowledge this message"), completionHandler: nil)
        }
    }

    override func awakeFromNib() {
    }
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        
        // check if we are root
        if getuid() != 0 {
            showWarning("Anwendung kann nur über den FAUmac Self Service gestartet werden!", buttonText: NSLocalizedString("Close", comment: "Close the application"), completionHandler: nil)
        } else {
            // jump into reason field
            self.window?.makeFirstResponder(textFieldReason)
        }
        
        // set textfields, of possible
        // get fqdn
        if var fqdn = NSHost.currentHost().name {
            fqdn = fqdn.stringByReplacingOccurrencesOfString(".local", withString: "")
            textFieldComputerName.stringValue = fqdn
        }

        // get User Name
        if let username = SCDynamicStoreCopyConsoleUser(nil, nil, nil) {
            // get real Name
            let (realName, _) = getSTDOUTfromCommand("/usr/bin/dscl", arguments: [".", "read", "/Users/\(username)", "RealName"])
            if var realName = realName {
                // remove garbage
                realName = realName.stringByReplacingOccurrencesOfString("RealName:", withString: "")
                realName = realName.stringByReplacingOccurrencesOfString("\n", withString: "")
                realName = realName.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                textFieldName.stringValue = realName
            }
            // get Email
            let (EMail, _) = getSTDOUTfromCommand("/usr/bin/dscl", arguments: [".", "read", "/Users/\(username)", "EMailAddress"])
            if var EMail = EMail {
                // remove garbage
                EMail = EMail.stringByReplacingOccurrencesOfString("EMailAddress:", withString: "")
                EMail = EMail.stringByReplacingOccurrencesOfString("\n", withString: "")
                EMail = EMail.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                textFieldEMail.stringValue = EMail
            }
        }
        // disable until all fields are filled
        buttonSend.enabled = false
        
        // delegates for NSTextFieldDelegate / controlTextDidChange()
        textFieldName.delegate = self
        textFieldEMail.delegate = self
        textFieldReason.delegate = self
        textFieldComputerName.delegate = self
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    // close App with close button
    func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication) -> Bool {
        return true
    }
    
    @IBAction func buttonClose(sender: AnyObject) {
        self.quit()
    }
    
    @IBAction func buttonSend(sender: AnyObject) {
        // disable send button while doing network IO
        self.buttonSend.enabled = false
        self.progressIndicator.startAnimation(self)
        let request = NSMutableURLRequest(URL: NSURL(string: Config.putURL)!)
        request.HTTPMethod = "PUT"
        request.timeoutInterval = 5.0
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let data = "Name=\(self.textFieldName.stringValue)&EMail=\(self.textFieldEMail.stringValue)&Descr=\(self.textFieldReason.stringValue)&MacName=\(self.textFieldComputerName.stringValue)"
        request.HTTPBody = (data as NSString).dataUsingEncoding(NSUTF8StringEncoding)
        #if DEBUG
            NSLog("We are in Debug Mode, so we assume, that the API Call works!")
            NSThread.sleepForTimeInterval(1.0)
            grantAdminRights()
        #else
            NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue(), completionHandler: {(response: NSHTTPURLResponse?, data: NSData?, error: NSError?) -> Void in
                guard error == nil else {
                    self.showWarning(NSLocalizedString("Could not connect to the server to send your request. Please establish a network connection and try again.", comment: "could not send the request to our server for processing"), completionHandler: nil)
                    return
                }
                guard response.statusCode == 200 else {
                    self.showWarning(NSLocalizedString("Server returned an error. Are you eligible for getting admin rights?", comment: "the server had an error processing or the user is not eligible to have admin rights"), completionHandler: nil)
                    return
                }
                
                // we just check the returncode, you may add your own logic in here ...
                self.grantAdminRights()
            })
        #endif
    }
    
    // check if we can enable the send button
    override func controlTextDidChange(obj: NSNotification) {
        if (textFieldName.stringValue != "" &&
            textFieldEMail.stringValue != "" &&
            textFieldReason.stringValue != "" &&
            textFieldComputerName.stringValue != "")
        {
            buttonSend.enabled = true
        } else {
            buttonSend.enabled = false
        }
    }
    
    func grantAdminRights() {
        // get username
        guard let username = SCDynamicStoreCopyConsoleUser(nil, nil, nil) as? String else {
            showWarning(NSLocalizedString("could not get your local username, exiting!", comment: "did not get the currently logged in user"), buttonText: NSLocalizedString("Close", comment: "Close the application"), completionHandler: { _ in
                self.quit()
            })
            return
        }
        
        var task = NSTask.launchedTaskWithLaunchPath("/bin/launchctl", arguments: ["list", Config.launchdJobIdentifier])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            NSTask.launchedTaskWithLaunchPath("/bin/launchctl", arguments: ["unload", "-w", "/Library/LaunchDaemons/\(Config.launchdJobIdentifier).plist"])
        }
        
        let scriptPath = NSBundle.mainBundle().pathForImageResource("MakeMeAdmin-remove.sh")
        // write and launch launchd job
        let plist: String = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n" +
            "<plist version=\"1.0\">\n" +
            "   <dict>\n" +
            "   <key>Disabled</key>\n" +
            "   <false/>\n" +
            "   <key>Label</key>\n" +
            "   <string>\(Config.launchdJobIdentifier)</string>\n" +
            "   <key>ProgramArguments</key>\n" +
            "   <array>\n" +
            "       <string>\(scriptPath)</string>\n" +
            "       <string>\(username)</string>\n" +
            "   </array>\n" +
            "   <key>StartInterval</key>\n" +
            "   <integer>1800</integer>\n" +
            "   </dict>\n" +
        "</plist>\n"
        do {
            try plist.writeToFile("/Library/LaunchDaemons/\(Config.launchdJobIdentifier).plist", atomically: false, encoding: NSUTF8StringEncoding)
        } catch {
            showWarning(NSLocalizedString("could not create launchd job!", comment: "there was an error creating the job that removes the administrative rights"), buttonText: NSLocalizedString("Close", comment: "Close the application"), completionHandler: { _ in
                self.quit()
            })
        }
        NSTask.launchedTaskWithLaunchPath("/bin/launchctl", arguments: ["load", "-w", "/Library/LaunchDaemons/\(Config.launchdJobIdentifier).plist"])
        
        // log admin request
        let components = NSCalendar.currentCalendar().components([.Year, .Month, .Day, .Hour, .Minute, .Second], fromDate: NSDate())
        let str = "\n\(components.day)/\(components.month)/\(components.year) \(components.hour):\(components.minute):\(components.second) by \(username)"
        if let data = str.dataUsingEncoding(NSUTF8StringEncoding) {
            if let f = NSFileHandle(forWritingAtPath: Config.logFile) {
                f.seekToEndOfFile()
                f.writeData(data)
            } else {
                NSLog("cannot open \(Config.logFile) for writing.")
                NSFileManager.defaultManager().createFileAtPath(Config.logFile, contents: data, attributes: nil)
            }
        } else {
            NSLog("string to data cast failed!")
        }
        
        // we save a machine readable plist which contains all users that have used MakeMeAdmin on this machine
        // /var/root/Library/Preferences/de.uni-erlangen.rrze.MakeMeAdmin.plist
        let defaults = NSUserDefaults.standardUserDefaults()
        if var users = defaults.arrayForKey("enabledUsers") as? [String] {
            if !users.contains(username as String) {
                users.append(username as String)
                defaults.setObject(users, forKey: "enabledUsers")
            }
        } else {
            defaults.setObject(["\(username)"], forKey: "enabledUsers")
        }
        
        // add user to admin group
        task = NSTask.launchedTaskWithLaunchPath("/usr/sbin/dseditgroup", arguments: ["-o", "edit", "-a", username as String!, "-t", "user", "admin"])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            showWarning(
                NSLocalizedString("You have now Admin Rights for 30 minutes! Run this utility againt to gain another 30 minutes",
                    comment: "Inform the user that he has the right to administer this computer for 30 minutes"),
                buttonText: NSLocalizedString("Close", comment: "Close the application"),
                completionHandler: { _ in
                    self.quit()
            })
        } else {
            // the exit code was != 0
            showWarning(NSLocalizedString("Could not add you to the administrator group.", comment: "there was an error adding the user to the group of users that may administer this computer"), buttonText: NSLocalizedString("Ok", comment: "aknowledge this message"), completionHandler: { _ in
                self.quit()
            })
        }
    }
    
    func getSTDOUTfromCommand(path: String, arguments: [String]) -> (String?, Int) {
        let pipe = NSPipe()
        let task = NSTask()
        task.launchPath = path
        task.arguments = arguments
        // if we use NSTask.launchedTaskWithLaunchPath() we cannot attach pipe because the task already runs when attaching
        task.standardOutput = pipe
        task.standardError = pipe
        task.launch()
        task.waitUntilExit()
        let stdout = NSString(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: NSUTF8StringEncoding) as? String
        return (stdout, Int(task.terminationStatus))
    }

    func showWarning(messageText: String, buttonText: String, completionHandler: ((NSModalResponse) -> Void)?) {
        self.progressIndicator.stopAnimation(self)
        self.buttonSend.enabled = true
        let alert = NSAlert()
        alert.alertStyle = .WarningAlertStyle
        alert.addButtonWithTitle(buttonText)
        alert.messageText = messageText
        // we need to get back to main thread if we are not there
        dispatch_async(dispatch_get_main_queue(), {
            alert.beginSheetModalForWindow(self.window!, completionHandler: completionHandler)
        })
    }
    
    func quit() {
        NSApplication.sharedApplication().terminate(self)
    }

}

