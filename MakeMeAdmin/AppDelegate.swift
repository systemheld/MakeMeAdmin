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
    @IBAction func showLogfile(_ sender: AnyObject) {
        if FileManager.default.fileExists(atPath: Config.logFile) {
            Process.launchedProcess(launchPath: "/usr/bin/open", arguments: ["-a", "Console", Config.logFile])
        } else {
            showWarning(NSLocalizedString("There is no log file. Is this the first time you run this?", comment: "no log file was created until now"), buttonText: NSLocalizedString("Ok", comment: "aknowledge this message"), completionHandler: nil)
        }
    }

    override func awakeFromNib() {
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        // check if we are root
        if getuid() != 0 {
            showWarning(NSLocalizedString("This application may be run only from FAUmac Self Service!", comment: "For security reasons this application does not have the setuid bit set. It must be run from root in some way, we use JAMF Self Service for that."), buttonText: NSLocalizedString("Close", comment: "Close the application"), completionHandler: { _ in
                self.quit()
            })
        } else {
            // jump into reason field
            self.window?.makeFirstResponder(textFieldReason)
        }
        
        // set textfields, of possible
        // get fqdn
        if var fqdn = Host.current().name {
            fqdn = fqdn.replacingOccurrences(of: ".local", with: "")
            textFieldComputerName.stringValue = fqdn
        }

        // get User Name
        if let username = SCDynamicStoreCopyConsoleUser(nil, nil, nil) {
            // get real Name
            let (realName, _) = getSTDOUTfromCommand("/usr/bin/dscl", arguments: [".", "read", "/Users/\(username)", "RealName"])
            if var realName = realName {
                // remove garbage
                realName = realName.replacingOccurrences(of: "RealName:", with: "")
                realName = realName.replacingOccurrences(of: "\n", with: "")
                realName = realName.trimmingCharacters(in: CharacterSet.whitespaces)
                textFieldName.stringValue = realName
            }
            // get Email
            let (EMail, _) = getSTDOUTfromCommand("/usr/bin/dscl", arguments: [".", "read", "/Users/\(username)", "EMailAddress"])
            if var EMail = EMail {
                // remove garbage
                EMail = EMail.replacingOccurrences(of: "EMailAddress:", with: "")
                EMail = EMail.replacingOccurrences(of: "\n", with: "")
                EMail = EMail.trimmingCharacters(in: CharacterSet.whitespaces)
                textFieldEMail.stringValue = EMail
            }
        }
        // disable until all fields are filled
        buttonSend.isEnabled = false
        
        // delegates for NSTextFieldDelegate / controlTextDidChange()
        textFieldName.delegate = self
        textFieldEMail.delegate = self
        textFieldReason.delegate = self
        textFieldComputerName.delegate = self
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    // close App with close button
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    @IBAction func buttonClose(_ sender: AnyObject) {
        self.quit()
    }
    
    @IBAction func buttonSend(_ sender: AnyObject) {
        // disable send button while doing network IO
        self.buttonSend.isEnabled = false
        self.progressIndicator.startAnimation(self)
        var request = URLRequest(url: URL(string: Config.putURL)!)
        request.httpMethod = "PUT"
        request.timeoutInterval = 5.0
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let data = "Name=\(self.textFieldName.stringValue)&EMail=\(self.textFieldEMail.stringValue)&Descr=\(self.textFieldReason.stringValue)&MacName=\(self.textFieldComputerName.stringValue)"
        request.httpBody = (data as NSString).data(using: String.Encoding.utf8.rawValue)
        #if DEBUG
            NSLog("We are in Debug Mode, so we assume, that the API Call works!")
            Thread.sleep(forTimeInterval: 1.0)
            grantAdminRights()
        #else
            URLSession.shared.dataTask(with: request, completionHandler: {(data: Data?, response: URLResponse?, error: Error?) -> Void in
                guard error == nil else {
                    self.showWarning(NSLocalizedString("Could not connect to the server to send your request. Please establish a network connection and try again.", comment: "could not send the request to our server for processing"),
                                     buttonText: NSLocalizedString("Close", comment: "Close the application"),
                                     completionHandler: nil)
                    return
                }
                guard let response = response as? HTTPURLResponse else {
                    self.showWarning(NSLocalizedString("Server returned malformed content. Please try again later.", comment: "the server answer was not readable, either there were network problems or server problems."),
                                     buttonText: NSLocalizedString("Close", comment: "Close the application"),
                                     completionHandler: nil)
                    return
                }
                guard response.statusCode == 200 else {
                    self.showWarning(NSLocalizedString("Server returned an error. Are you eligible for getting admin rights?", comment: "the server had an error processing or the user is not eligible to have admin rights"),
                                     buttonText: NSLocalizedString("Close", comment: "Close the application"),
                                     completionHandler: nil)
                    return
                }
                
                // we just check the returncode, you may add your own logic in here ...
                self.grantAdminRights()
            }).resume()
        #endif
    }
    
    // check if we can enable the send button
    override func controlTextDidChange(_ obj: Notification) {
        if (textFieldName.stringValue != "" &&
            textFieldEMail.stringValue != "" &&
            textFieldReason.stringValue != "" &&
            textFieldComputerName.stringValue != "")
        {
            buttonSend.isEnabled = true
        } else {
            buttonSend.isEnabled = false
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
        
        var task = Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["list", Config.launchdJobIdentifier])
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["unload", "-w", "/Library/LaunchDaemons/\(Config.launchdJobIdentifier).plist"])
        }
        
        let scriptPath = Bundle.main.pathForImageResource("MakeMeAdmin-remove.sh")
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
            try plist.write(toFile: "/Library/LaunchDaemons/\(Config.launchdJobIdentifier).plist", atomically: false, encoding: String.Encoding.utf8)
        } catch {
            showWarning(NSLocalizedString("could not create launchd job!", comment: "there was an error creating the job that removes the administrative rights"), buttonText: NSLocalizedString("Close", comment: "Close the application"), completionHandler: { _ in
                self.quit()
            })
        }
        Process.launchedProcess(launchPath: "/bin/launchctl", arguments: ["load", "-w", "/Library/LaunchDaemons/\(Config.launchdJobIdentifier).plist"])
        
        // log admin request
        let components = (Calendar.current as NSCalendar).components([.year, .month, .day, .hour, .minute, .second], from: Date())
        let str = "\n\(components.day)/\(components.month)/\(components.year) \(components.hour):\(components.minute):\(components.second) by \(username)"
        if let data = str.data(using: String.Encoding.utf8) {
            if let f = FileHandle(forWritingAtPath: Config.logFile) {
                f.seekToEndOfFile()
                f.write(data)
            } else {
                NSLog("cannot open \(Config.logFile) for writing.")
                FileManager.default.createFile(atPath: Config.logFile, contents: data, attributes: nil)
            }
        } else {
            NSLog("string to data cast failed!")
        }
        
        // we save a machine readable plist which contains all users that have used MakeMeAdmin on this machine
        // /var/root/Library/Preferences/de.uni-erlangen.rrze.MakeMeAdmin.plist
        let defaults = UserDefaults.standard
        if var users = defaults.array(forKey: "enabledUsers") as? [String] {
            if !users.contains(username as String) {
                users.append(username as String)
                defaults.set(users, forKey: "enabledUsers")
            }
        } else {
            defaults.set(["\(username)"], forKey: "enabledUsers")
        }
        
        // add user to admin group
        task = Process.launchedProcess(launchPath: "/usr/sbin/dseditgroup", arguments: ["-o", "edit", "-a", username as String!, "-t", "user", "admin"])
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
    
    func getSTDOUTfromCommand(_ path: String, arguments: [String]) -> (String?, Int) {
        let pipe = Pipe()
        let task = Process()
        task.launchPath = path
        task.arguments = arguments
        // if we use NSTask.launchedTaskWithLaunchPath() we cannot attach pipe because the task already runs when attaching
        task.standardOutput = pipe
        task.standardError = pipe
        task.launch()
        task.waitUntilExit()
        let stdout = NSString(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: String.Encoding.utf8.rawValue) as? String
        return (stdout, Int(task.terminationStatus))
    }

    func showWarning(_ messageText: String, buttonText: String, completionHandler: ((NSModalResponse) -> Void)?) {
        self.progressIndicator.stopAnimation(self)
        self.buttonSend.isEnabled = true
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.addButton(withTitle: buttonText)
        alert.messageText = messageText
        // we need to get back to main thread if we are not there
        DispatchQueue.main.async(execute: {
            // causes an autolayout error:
            //
            // [Layout] Detected missing constraints for <private>.  It cannot be placed because there are not enough constraints 
            // to fully define the size and origin. Add the missing constraints, or set translatesAutoresizingMaskIntoConstraints=YES
            // and constraints will be generated for you. If this view is laid out manually on macOS 10.12 and later, you may choose
            // to not call [super layout] from your override. Set a breakpoint on DETECTED_MISSING_CONSTRAINTS to debug. This error 
            // will only be logged once.
            alert.beginSheetModal(for: self.window!, completionHandler: completionHandler)
        })
    }
    
    func quit() {
        NSApplication.shared().terminate(self)
    }

}

