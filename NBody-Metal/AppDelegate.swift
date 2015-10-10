//
//  AppDelegate.swift
//  NBody-Metal
//
//  Created by James Price on 08/10/2015.
//  Copyright © 2015 James Price. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  @IBOutlet weak var window: NSWindow!

  func applicationDidFinishLaunching(aNotification: NSNotification) {
    window.title = "NBody-Metal"
  }

  func applicationWillTerminate(aNotification: NSNotification) {
  }

  func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication) -> Bool {
    return true
  }
}

