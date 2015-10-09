//
//  NBodyViewController.swift
//  NBody-Metal
//
//  Created by James Price on 09/10/2015.
//  Copyright © 2015 James Price. All rights reserved.
//

import MetalKit

class NBodyViewController: NSViewController, MTKViewDelegate {

  private let WIDTH  = 640
  private let HEIGHT = 480

  override func viewDidLoad() {
    super.viewDidLoad()

    self.view.window?.setContentSize(NSSize(width: WIDTH, height: HEIGHT))

    let metalview = MTKView(frame: CGRect(x: 0, y: 0, width: WIDTH, height: HEIGHT), device: MTLCreateSystemDefaultDevice())
    metalview.delegate = self
    view.addSubview(metalview)
  }

  func drawInMTKView(view: MTKView) {
  }

  func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
  }
}
