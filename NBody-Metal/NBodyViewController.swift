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

  private var queue: MTLCommandQueue!

  override func viewDidLoad() {
    super.viewDidLoad()

    self.view.window?.setContentSize(NSSize(width: WIDTH, height: HEIGHT))

    let metalview = MTKView(frame: CGRect(x: 0, y: 0, width: WIDTH, height: HEIGHT))
    metalview.delegate = self
    view.addSubview(metalview)

    let device = MTLCreateSystemDefaultDevice()!
    queue = device.newCommandQueue()
    metalview.device = device
  }

  func drawInMTKView(view: MTKView) {
    let renderPassDescriptor = view.currentRenderPassDescriptor
    renderPassDescriptor!.colorAttachments[0].loadAction = .Clear
    renderPassDescriptor!.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.2, 1.0)

    let buffer = queue.commandBuffer()
    let encoder = buffer.renderCommandEncoderWithDescriptor(renderPassDescriptor!)

    encoder.endEncoding()

    buffer.presentDrawable(view.currentDrawable!)
    buffer.commit()
  }

  func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
  }
}
