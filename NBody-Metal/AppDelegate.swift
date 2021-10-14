//
//  AppDelegate.swift
//  NBody-Metal
//
//  Created by James Price on 08/10/2015.
//  Copyright © 2015 James Price. All rights reserved.
//

import Cocoa

class Application : NSApplication {
  let strongDelegate = AppDelegate()
  override init(){
    super.init()
    self.delegate = strongDelegate
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

@NSApplicationMain
class AppDelegate : NSObject, NSApplicationDelegate {
  var window: NSWindow!

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    window.title = "NBody-Metal"

    var frame = window.frame
    frame.size.width = 1280
    frame.size.height = 720
    window.setFrame(frame, display: true)
    window.minSize = frame.size
    window.maxSize = frame.size
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}
