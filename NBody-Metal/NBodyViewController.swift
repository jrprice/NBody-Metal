//
//  NBodyViewController.swift
//  NBody-Metal
//
//  Created by James Price on 09/10/2015.
//  Copyright © 2015 James Price. All rights reserved.
//

import MetalKit

class NBodyViewController: NSViewController, MTKViewDelegate {

  private let WIDTH     = 640
  private let HEIGHT    = 480
  private let RADIUS    = Float(0.3)
  private let NBODIES   = 4096
  private let GROUPSIZE = 64
  private let DELTA     = Float(0.0001)
  private let SOFTENING = Float(0.1)

  private var queue: MTLCommandQueue!
  private var library: MTLLibrary!
  private var computePipelineState: MTLComputePipelineState!
  private var renderPipelineState: MTLRenderPipelineState!

  private var d_positions0: MTLBuffer!
  private var d_positions1: MTLBuffer!
  private var d_velocities: MTLBuffer!

  private var d_positionsIn:  MTLBuffer!
  private var d_positionsOut: MTLBuffer!

  private var d_params: MTLBuffer!

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

    // Initialise positions
    var h_positions = [Float]()
    for _ in 1...NBODIES {
      let angle = 2.0 * Float(M_PI) * (Float(rand())/Float(RAND_MAX))
      h_positions.append(RADIUS * cos(angle))
      h_positions.append(RADIUS * sin(angle))
      h_positions.append(0.0)
      h_positions.append(1.0)
    }
    d_positions0 = device.newBufferWithBytes(h_positions, length: sizeof(float4)*NBODIES, options: MTLResourceOptions.CPUCacheModeDefaultCache)
    d_positions1 = device.newBufferWithLength(sizeof(float4)*NBODIES, options: MTLResourceOptions.CPUCacheModeDefaultCache)
    d_velocities = device.newBufferWithLength(sizeof(float4)*NBODIES, options: MTLResourceOptions.CPUCacheModeDefaultCache)

    struct Params {
      var nbodies:UInt32  = 0
      var delta:Float     = 0
      var softening:Float = 0
    }
    var h_params = Params(nbodies: UInt32(NBODIES), delta: DELTA, softening: SOFTENING)
    d_params = device.newBufferWithBytes(&h_params, length: sizeof(Params), options: MTLResourceOptions.CPUCacheModeDefaultCache)

    d_positionsIn = d_positions0
    d_positionsOut = d_positions1
  }

  func drawInMTKView(view: MTKView) {
    let renderPassDescriptor = view.currentRenderPassDescriptor
    renderPassDescriptor!.colorAttachments[0].loadAction = .Clear
    renderPassDescriptor!.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.2, 1.0)

    let buffer = queue.commandBuffer()

    // Compute kernel
    let groupsize = MTLSizeMake(GROUPSIZE, 1, 1)
    let numgroups = MTLSizeMake(NBODIES/GROUPSIZE, 1, 1)
    let computeEncoder = buffer.computeCommandEncoder()
    computeEncoder.setComputePipelineState(computePipelineState)
    computeEncoder.setBuffer(d_positionsIn, offset: 0, atIndex: 0)
    computeEncoder.setBuffer(d_positionsOut, offset: 0, atIndex: 1)
    computeEncoder.setBuffer(d_velocities, offset: 0, atIndex: 2)
    computeEncoder.setBuffer(d_params, offset: 0, atIndex: 3)
    computeEncoder.dispatchThreadgroups(numgroups, threadsPerThreadgroup: groupsize)
    computeEncoder.endEncoding()

    // Vertex and fragment shaders
    let renderEncoder  = buffer.renderCommandEncoderWithDescriptor(renderPassDescriptor!)
    renderEncoder.setRenderPipelineState(renderPipelineState)
    renderEncoder.setVertexBuffer(d_positionsOut, offset: 0, atIndex: 0)
    renderEncoder.drawPrimitives(.Point, vertexStart: 0, vertexCount: NBODIES)
    renderEncoder.endEncoding()

    buffer.presentDrawable(view.currentDrawable!)
    buffer.commit()

    swap(&d_positionsIn, &d_positionsOut)
  }

  func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
  }
}
