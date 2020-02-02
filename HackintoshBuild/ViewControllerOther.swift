//
//  ViewControllerOther.swift
//  HackintoshBuild
//
//  Created by 刘靖禹 on 2020/1/17.
//  Copyright © 2020 Arabaku. All rights reserved.
//

import Cocoa

class ViewControllerOther: NSViewController {
    
    @IBOutlet weak var sipLable: NSTextField!
    @IBOutlet var output: NSTextView!
    @IBOutlet var progressBar: NSProgressIndicator!
    @IBOutlet weak var unclockButton: NSButton!
    @IBOutlet weak var rebuildButton: NSButton!
    @IBOutlet weak var spctlButton: NSButton!
    
    var task:Process!
    var outputPipe:Pipe!
    
    let taskQueue = DispatchQueue.global(qos: .background)
    let lock = NSLock()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        progressBar.isHidden = true
        let sipStatus = UserDefaults().string(forKey: "sipStatus") ?? ""
        MyLog(sipStatus)
        spctlButton.isEnabled = true
        if sipStatus == "SIP已关闭" {
            sipLable.textColor = NSColor.green
            sipLable.stringValue = "SIP已关闭"
            unclockButton.isEnabled = true
            rebuildButton.isEnabled = true
        }
        else {
            sipLable.textColor = NSColor.red
            sipLable.stringValue = "SIP未关闭,请先关闭SIP"
            unclockButton.isEnabled = false
            rebuildButton.isEnabled = false
        }
    }
    
    @IBAction func unlockSLE(_ sender: Any) {
        
        output.string = ""
        progressBar.isHidden = true
        
        if #available(OSX 10.15, *) {
            runBuildScripts("unlockSLE", "SLE解锁成功")
        }

        else {
            let alert = NSAlert()
            alert.messageText = "系统版本低于10.15，无需解锁"
            alert.runModal()
        }
    }
    
    @IBAction func rebuildCache(_ sender: Any) {
        progressBar.isHidden = false
        output.string = ""
        self.progressBar.startAnimation(self)
        
        runBuildScripts("rebuildCache", "修复权限以及重建缓存成功")
    }
    
    @IBAction func spctl(_ sender: Any) {
        output.string = ""
        progressBar.isHidden = true
        
        runBuildScripts("spctl", "已开启未知来源安装")
    }
    func runBuildScripts(_ shell: String,_ alertText: String) {
        taskQueue.async {
            if let path = Bundle.main.path(forResource: shell, ofType:"command") {
                let task = Process()
                task.launchPath = path
                task.terminationHandler = { task in
                DispatchQueue.main.async(execute: { [weak self] in
                    guard let `self` = self else { return }
                        self.lock.lock()
                        self.progressBar.isHidden = true
                        self.progressBar.stopAnimation(self)
                        self.progressBar.doubleValue = 0.0
                        let alert = NSAlert()
                        alert.messageText = alertText
                        alert.runModal()
                        self.lock.unlock()
                    })
                }
                self.taskOutPut(task)
                task.launch()
                task.waitUntilExit()
            }
        }
    }
    
    func taskOutPut(_ task:Process) {
        outputPipe = Pipe()
        task.standardOutput = outputPipe
        outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: outputPipe.fileHandleForReading , queue: nil) {
            notification in
            let output = self.outputPipe.fileHandleForReading.availableData
            let outputString = String(data: output, encoding: String.Encoding.utf8) ?? ""
            DispatchQueue.main.async(execute: {
                let previousOutput = self.output.string
                let nextOutput = previousOutput + "\n" + outputString
                self.output.string = nextOutput
                let range = NSRange(location:nextOutput.count,length:0)
                self.output.scrollRangeToVisible(range)
                self.progressBar.increment(by: 1.9)
            })
            self.outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        }
    }
    
}
