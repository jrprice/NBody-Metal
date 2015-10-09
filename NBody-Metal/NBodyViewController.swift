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
  private var library: MTLLibrary!
  private var pipelineState: MTLRenderPipelineState!

  private var d_vertices: MTLBuffer!

  override func viewDidLoad() {
    super.viewDidLoad()

    self.view.window?.setContentSize(NSSize(width: WIDTH, height: HEIGHT))

    let metalview = MTKView(frame: CGRect(x: 0, y: 0, width: WIDTH, height: HEIGHT))
    metalview.delegate = self
    view.addSubview(metalview)

    let device = MTLCreateSystemDefaultDevice()!
    queue      = device.newCommandQueue()
    library    = device.newDefaultLibrary()
    metalview.device = device

    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
    pipelineStateDescriptor.vertexFunction = library.newFunctionWithName("vert")
    pipelineStateDescriptor.fragmentFunction = library.newFunctionWithName("frag")
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
    do {
      pipelineState = try device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor)
    }
    catch {
      print("Failed to create render pipeline state")
    }

    let h_vertices:[Float] = [0.0, 0.0, 0.0]
    d_vertices = device.newBufferWithBytes(h_vertices, length: 12, options: MTLResourceOptions.CPUCacheModeDefaultCache)
  }

  func drawInMTKView(view: MTKView) {
    let renderPassDescriptor = view.currentRenderPassDescriptor
    renderPassDescriptor!.colorAttachments[0].loadAction = .Clear
    renderPassDescriptor!.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.2, 1.0)

    let buffer = queue.commandBuffer()
    let encoder = buffer.renderCommandEncoderWithDescriptor(renderPassDescriptor!)

    encoder.setRenderPipelineState(pipelineState)
    encoder.setVertexBuffer(d_vertices, offset: 0, atIndex: 0)
    encoder.drawPrimitives(.Point, vertexStart: 0, vertexCount: 1)

    encoder.endEncoding()

    buffer.presentDrawable(view.currentDrawable!)
    buffer.commit()
  }

  func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
  }
}
