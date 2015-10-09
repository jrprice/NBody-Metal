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
  private var computePipelineState: MTLComputePipelineState!
  private var renderPipelineState: MTLRenderPipelineState!

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

    do {
      computePipelineState = try device.newComputePipelineStateWithFunction(library.newFunctionWithName("step")!)
    }
    catch {
      print("Failed to create compute pipeline state")
    }

    let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
    renderPipelineStateDescriptor.vertexFunction = library.newFunctionWithName("vert")
    renderPipelineStateDescriptor.fragmentFunction = library.newFunctionWithName("frag")
    renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
    do {
      renderPipelineState = try device.newRenderPipelineStateWithDescriptor(renderPipelineStateDescriptor)
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

    let groupsize = MTLSizeMake(1, 1, 1)
    let numgroups = MTLSizeMake(1, 1, 1)


    let buffer = queue.commandBuffer()

    let computeEncoder = buffer.computeCommandEncoder()
    computeEncoder.setComputePipelineState(computePipelineState)
    computeEncoder.setBuffer(d_vertices, offset: 0, atIndex: 0)
    computeEncoder.dispatchThreadgroups(numgroups, threadsPerThreadgroup: groupsize)
    computeEncoder.endEncoding()

    let renderEncoder  = buffer.renderCommandEncoderWithDescriptor(renderPassDescriptor!)
    renderEncoder.setRenderPipelineState(renderPipelineState)
    renderEncoder.setVertexBuffer(d_vertices, offset: 0, atIndex: 0)
    renderEncoder.drawPrimitives(.Point, vertexStart: 0, vertexCount: 1)
    renderEncoder.endEncoding()

    buffer.presentDrawable(view.currentDrawable!)
    buffer.commit()
  }

  func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
  }
}
