//
//  NBodyViewController.swift
//  NBody-Metal
//
//  Created by James Price on 09/10/2015.
//  Copyright © 2015 James Price. All rights reserved.
//

import MetalKit

private let WIDTH     = 640
private let HEIGHT    = 480
private let RADIUS    = Float(0.8)
private let GROUPSIZE = 64 // must be same as GROUPSIZE in shaders.metal
private let DELTA     = Float(0.0001)
private let SOFTENING = Float(0.05)
private let MAXBODIES = 32768
private let MINBODIES = GROUPSIZE

class NBodyViewController: NSViewController, MTKViewDelegate {

  private var deviceIndex = 0
  private var nbodies     = 8192

  private var metalview: MTKView!

  private var queue: MTLCommandQueue?
  private var library: MTLLibrary!
  private var computePipelineState: MTLComputePipelineState!
  private var renderPipelineState: MTLRenderPipelineState!
  private var buffer: MTLCommandBuffer?

  private var d_positions0: MTLBuffer?
  private var d_positions1: MTLBuffer?
  private var d_velocities: MTLBuffer?

  private var d_positionsIn:  MTLBuffer?
  private var d_positionsOut: MTLBuffer?

  private var d_computeParams: MTLBuffer!
  private var d_renderParams:  MTLBuffer!

  private var projectionMatrix: Matrix4!

  private var frames = 0
  private var lastUpdate:Double = 0
  private var nametext:    NSTextField!
  private var nbodiestext: NSTextField!
  private var fpstext:     NSTextField!
  private var flopstext:   NSTextField!

  override func viewDidLoad() {
    super.viewDidLoad()

    self.view.window?.setContentSize(NSSize(width: WIDTH, height: HEIGHT))

    // Add view controller to responder chain
    self.view.window?.nextResponder = self
    self.nextResponder = nil

    // Create MTKView object
    metalview = MTKView(frame: CGRect(x: 0, y: 0, width: WIDTH, height: HEIGHT))
    metalview.delegate = self
    view.addSubview(metalview)

    // Create status labels
    nametext    = createInfoText(NSMakeRect(10, CGFloat(HEIGHT)-30, 300, 20))
    nbodiestext = createInfoText(NSMakeRect(10, CGFloat(HEIGHT)-50, 300, 20))
    fpstext     = createInfoText(NSMakeRect(10, CGFloat(HEIGHT)-70, 120, 20))
    flopstext   = createInfoText(NSMakeRect(10, CGFloat(HEIGHT)-90, 120, 20))
    metalview.addSubview(nametext)
    metalview.addSubview(nbodiestext)
    metalview.addSubview(fpstext)
    metalview.addSubview(flopstext)

    initMetal(false)
    initBodies()
  }

  func createInfoText(rect: NSRect) -> NSTextField {
    let text = NSTextField(frame: rect)
    text.editable        = false
    text.bezeled         = false
    text.selectable      = false
    text.drawsBackground = false
    text.textColor       = NSColor.whiteColor()
    text.font            = NSFont.boldSystemFontOfSize(14.0)
    text.stringValue     = ""

    return text
  }

  func drawInMTKView(view: MTKView) {

    // Update FPS and GFLOP/s counters
    frames += 1
    let now  = getTimestamp()
    let diff = now - lastUpdate
    if diff >= 1000 {
      let fps = (Double(frames) / diff) * 1000
      let strfps = NSString(format: "%.1f", fps)
      fpstext.stringValue = "FPS: \(strfps)"

      let flopsPerPair = 21.0
      let gflops = ((Double(frames) * Double(nbodies) * Double(nbodies) * flopsPerPair) / diff) * 1000 * 1e-9
      let strflops = NSString(format: "%.1f", gflops)
      flopstext.stringValue = "GFLOP/s: \(strflops)"

      frames = 0
      lastUpdate = now
    }

    buffer = queue?.commandBuffer()

    // Compute kernel
    let groupsize = MTLSizeMake(GROUPSIZE, 1, 1)
    let numgroups = MTLSizeMake(nbodies/GROUPSIZE, 1, 1)
    let computeEncoder = buffer!.computeCommandEncoder()
    computeEncoder.setComputePipelineState(computePipelineState)
    computeEncoder.setBuffer(d_positionsIn, offset: 0, atIndex: 0)
    computeEncoder.setBuffer(d_positionsOut, offset: 0, atIndex: 1)
    computeEncoder.setBuffer(d_velocities, offset: 0, atIndex: 2)
    computeEncoder.setBuffer(d_computeParams, offset: 0, atIndex: 3)
    computeEncoder.dispatchThreadgroups(numgroups, threadsPerThreadgroup: groupsize)
    computeEncoder.endEncoding()

    // Vertex and fragment shaders
    let renderPassDescriptor = view.currentRenderPassDescriptor
    renderPassDescriptor!.colorAttachments[0].loadAction = .Clear
    renderPassDescriptor!.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.1, 1.0)
    let renderEncoder  = buffer!.renderCommandEncoderWithDescriptor(renderPassDescriptor!)
    renderEncoder.setRenderPipelineState(renderPipelineState)
    renderEncoder.setVertexBuffer(d_positionsOut, offset: 0, atIndex: 0)
    renderEncoder.setVertexBuffer(d_renderParams, offset: 0, atIndex: 1)
    renderEncoder.drawPrimitives(.Point, vertexStart: 0, vertexCount: nbodies)
    renderEncoder.endEncoding()

    buffer!.presentDrawable(view.currentDrawable!)
    buffer!.commit()

    swap(&d_positionsIn, &d_positionsOut)
  }

  func getTimestamp() -> Double {
    var tv:timeval = timeval()
    gettimeofday(&tv, nil)
    return (Double(tv.tv_sec)*1e3 + Double(tv.tv_usec)*1e-3)
  }

  func initBodies() {
    buffer?.waitUntilCompleted()

    // Initialise positions uniformly at random on surface of sphere, with no velocity
    let h_positions  = unsafeBitCast(d_positionsIn!.contents(), UnsafeMutablePointer<Float>.self)
    let h_velocities = unsafeBitCast(d_velocities!.contents(), UnsafeMutablePointer<Float>.self)
    for i in 0...(nbodies-1) {
      let longitude = 2.0 * Float(M_PI) * (Float(rand())/Float(RAND_MAX))
      let latitude  = acos((2.0 * (Float(rand())/Float(RAND_MAX))) - 1.0)
      h_positions[i*4 + 0] = RADIUS * sin(latitude) * cos(longitude)
      h_positions[i*4 + 1] = RADIUS * sin(latitude) * sin(longitude)
      h_positions[i*4 + 2] = RADIUS * cos(latitude)
      h_positions[i*4 + 3] = 1.0

      h_velocities[i*4 + 0] = 0.0
      h_velocities[i*4 + 1] = 0.0
      h_velocities[i*4 + 2] = 0.0
      h_velocities[i*4 + 3] = 0.0
    }

    d_positionsIn?.didModifyRange(NSMakeRange(0, sizeof(float4)*nbodies))
    d_velocities?.didModifyRange(NSMakeRange(0, sizeof(float4)*nbodies))
  }

  func initMetal(retainBodies: Bool) {

    // Get data from previous device
    let h_positions  = d_positionsIn?.contents()
    let h_velocities = d_velocities?.contents()
    let buffer       = queue?.commandBuffer()
    let blitEncoder  = buffer?.blitCommandEncoder()
    blitEncoder?.synchronizeResource(d_positionsIn!)
    blitEncoder?.synchronizeResource(d_velocities!)
    blitEncoder?.endEncoding()
    buffer?.commit()
    buffer?.waitUntilCompleted()

    // Select next device
    let device = MTLCopyAllDevices()[deviceIndex]
    nametext.stringValue = "Device: \(device.name!) [d]"
    nbodiestext.stringValue = "Bodies: \(nbodies) [+/-]"
    metalview.device = device

    queue      = device.newCommandQueue()
    library    = device.newDefaultLibrary()
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
    renderPipelineStateDescriptor.colorAttachments[0].blendingEnabled = true
    renderPipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .One
    renderPipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .One
    do {
      renderPipelineState = try device.newRenderPipelineStateWithDescriptor(renderPipelineStateDescriptor)
    }
    catch {
      print("Failed to create render pipeline state")
    }

    // Create device buffers
    let datasize = sizeof(float4)*nbodies
    d_positions0 = device.newBufferWithLength(datasize, options: .StorageModeManaged)
    d_positions1 = device.newBufferWithLength(datasize, options: .StorageModeManaged)
    d_velocities = device.newBufferWithLength(datasize, options: .StorageModeManaged)

    // Copy data from previous device
    if retainBodies {
      if h_positions != nil {
        memcpy(d_positions0!.contents(), h_positions!, datasize)
        d_positions0?.didModifyRange(NSMakeRange(0, datasize))
      }
      if h_velocities != nil {
        memcpy(d_velocities!.contents(), h_velocities!, datasize)
        d_velocities?.didModifyRange(NSMakeRange(0, datasize))
      }
    }

    d_positionsIn  = d_positions0
    d_positionsOut = d_positions1

    struct ComputeParams {
      var nbodies:UInt32  = 0
      var delta:Float     = 0
      var softening:Float = 0
    }
    var h_computeParams = ComputeParams(nbodies: UInt32(nbodies), delta: DELTA, softening: SOFTENING)
    d_computeParams = device.newBufferWithBytes(&h_computeParams, length: sizeof(ComputeParams), options: .CPUCacheModeDefaultCache)

    // Initialise view-projection matrices
    let vpMatrix = Matrix4()
    vpMatrix.translate(0.0, y: 0.0, z: -2.0)
    projectionMatrix = Matrix4.makePerspectiveViewAngle(Matrix4.degreesToRad(55.0), aspectRatio: Float(WIDTH)/Float(HEIGHT), nearZ: 0.1, farZ: 50.0)
    vpMatrix.multiplyLeft(projectionMatrix)

    var eyePosition = float3(0, 0, 2.0)

    let renderParamsSize = sizeof(matrix_float4x4) + sizeof(Float)*4
    d_renderParams = device.newBufferWithLength(renderParamsSize, options: .CPUCacheModeDefaultCache)
    memcpy(d_renderParams.contents(), vpMatrix.raw(), sizeof(matrix_float4x4))
    memcpy(d_renderParams.contents() + sizeof(matrix_float4x4), &eyePosition, sizeof(float3))
  }

  override func keyDown(theEvent: NSEvent) {
    switch theEvent.keyCode {
    case 2:
      // Select next device
      if ++deviceIndex >= MTLCopyAllDevices().count {
        deviceIndex = 0
      }
      initMetal(true)
    case 15:
      initBodies()
    case 12:
      exit(0)
    case 27:
      if nbodies > MINBODIES {
        nbodies /= 2
        initMetal(false)
        initBodies()
      }
    case 24:
      if theEvent.modifierFlags.contains(NSEventModifierFlags.ShiftKeyMask) {
        if nbodies < MAXBODIES {
          nbodies *= 2
          initMetal(false)
          initBodies()
        }
      }
    default:
      super.keyDown(theEvent)
    }
  }

  func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
  }
}
