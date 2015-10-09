//
//  NBodyViewController.swift
//  NBody-Metal
//
//  Created by James Price on 09/10/2015.
//  Copyright © 2015 James Price. All rights reserved.
//

import MetalKit

class NBodyViewController: NSViewController, MTKViewDelegate {

  override func viewDidLoad() {
    super.viewDidLoad()

    let metalview = MTKView(frame: CGRect(x:0, y:0, width:640, height:480), device: MTLCreateSystemDefaultDevice())
    metalview.delegate = self
    view.addSubview(metalview)
  }

  func drawInMTKView(view: MTKView) {
  }

  func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
  }
}
