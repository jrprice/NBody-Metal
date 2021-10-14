//
//  NBodyViewController.swift
//  NBody-Metal
//
//  Created by James Price on 09/10/2015.
//  Copyright © 2015 James Price. All rights reserved.
//

import GLKit
import MetalKit

private let WIDTH     = 1280
private let HEIGHT    = 720
private let RADIUS    = Float(0.6)
private let GROUPSIZE = 64 // must be same as GROUPSIZE in shaders.metal
private let DELTA     = Float(0.000025)
private let SOFTENING = Float(0.2)
private let MAXBODIES = 131072
private let MINBODIES = GROUPSIZE

class NBodyViewController: NSViewController, MTKViewDelegate {

  typealias float3 = SIMD3<Float>
  typealias float4 = SIMD4<Float>

  private var deviceIndex = 0
  private var nbodies     = 16384

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
    nametext    = createInfoText(rect: NSMakeRect(10, CGFloat(HEIGHT)-30, 300, 20))
    nbodiestext = createInfoText(rect: NSMakeRect(10, CGFloat(HEIGHT)-50, 300, 20))
    fpstext     = createInfoText(rect: NSMakeRect(10, CGFloat(HEIGHT)-70, 120, 20))
    flopstext   = createInfoText(rect: NSMakeRect(10, CGFloat(HEIGHT)-90, 120, 20))
    metalview.addSubview(nametext)
    metalview.addSubview(nbodiestext)
    metalview.addSubview(fpstext)
    metalview.addSubview(flopstext)

    initMetal(retainBodies: false)
    initBodies()
  }

  func createInfoText(rect: NSRect) -> NSTextField {
    let text = NSTextField(frame: rect)
    text.isEditable      = false
    text.isBezeled       = false
    text.isSelectable    = false
    text.drawsBackground = false
    text.textColor       = NSColor.white
    text.font            = NSFont.boldSystemFont(ofSize: 14.0)
    text.stringValue     = ""

    return text
  }

  func draw(in view: MTKView) {
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

    buffer = queue?.makeCommandBuffer()

    // Compute kernel
    let groupsize = MTLSizeMake(GROUPSIZE, 1, 1)
    let numgroups = MTLSizeMake(nbodies/GROUPSIZE, 1, 1)
    let computeEncoder = buffer!.makeComputeCommandEncoder()
    computeEncoder!.setComputePipelineState(computePipelineState)
    computeEncoder!.setBuffer(d_positionsIn, offset: 0, index: 0)
    computeEncoder!.setBuffer(d_positionsOut, offset: 0, index: 1)
    computeEncoder!.setBuffer(d_velocities, offset: 0, index: 2)
    computeEncoder!.setBuffer(d_computeParams, offset: 0, index: 3)
    computeEncoder!.dispatchThreadgroups(numgroups, threadsPerThreadgroup: groupsize)
    computeEncoder!.endEncoding()

    // Vertex and fragment shaders
    let renderPassDescriptor = view.currentRenderPassDescriptor
    renderPassDescriptor!.colorAttachments[0].loadAction = .clear
    renderPassDescriptor!.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.1, 1.0)
    let renderEncoder  = buffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
    renderEncoder!.setRenderPipelineState(renderPipelineState)
    renderEncoder!.setVertexBuffer(d_positionsOut, offset: 0, index: 0)
    renderEncoder!.setVertexBuffer(d_renderParams, offset: 0, index: 1)
    renderEncoder!.drawPrimitives(type: .point, vertexStart: 0, vertexCount: nbodies)
    renderEncoder!.endEncoding()

    buffer!.present(view.currentDrawable!)
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
    let h_positions  = d_positionsIn!.contents().assumingMemoryBound(to: Float.self)
    let h_velocities = d_velocities!.contents().assumingMemoryBound(to: Float.self)
    for i in 0...(nbodies-1) {
      let longitude = 2.0 * Float.pi * Float.random(in: 0..<1)
      let latitude  = acos((2.0 * Float.random(in: 0..<1)) - 1.0)
      h_positions[i*4 + 0] = RADIUS * sin(latitude) * cos(longitude)
      h_positions[i*4 + 1] = RADIUS * sin(latitude) * sin(longitude)
      h_positions[i*4 + 2] = RADIUS * cos(latitude)
      h_positions[i*4 + 3] = 1.0

      h_velocities[i*4 + 0] = 0.0
      h_velocities[i*4 + 1] = 0.0
      h_velocities[i*4 + 2] = 0.0
      h_velocities[i*4 + 3] = 0.0
    }

    d_positionsIn?.didModifyRange(0..<(MemoryLayout<float4>.size * nbodies))
    d_velocities?.didModifyRange(0..<(MemoryLayout<float4>.size * nbodies))
  }

  func initMetal(retainBodies: Bool) {

    // Get data from previous device
    let h_positions  = d_positionsIn?.contents()
    let h_velocities = d_velocities?.contents()
    let buffer       = queue?.makeCommandBuffer()
    let blitEncoder  = buffer?.makeBlitCommandEncoder()
    blitEncoder?.synchronize(resource: d_positionsIn!)
    blitEncoder?.synchronize(resource: d_velocities!)
    blitEncoder?.endEncoding()
    buffer?.commit()
    buffer?.waitUntilCompleted()

    // Select next device
    let device = MTLCopyAllDevices()[deviceIndex]
    nametext.stringValue = "Device: \(device.name) [d]"
    nbodiestext.stringValue = "Bodies: \(nbodies) [+/-]"
    metalview.device = device

    queue      = device.makeCommandQueue()
    library    = device.makeDefaultLibrary()
    do {
        computePipelineState = try device.makeComputePipelineState(function: library.makeFunction(name: "step")!)
    }
    catch {
      print("Failed to create compute pipeline state")
    }

    let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
    renderPipelineStateDescriptor.vertexFunction = library.makeFunction(name: "vert")
    renderPipelineStateDescriptor.fragmentFunction = library.makeFunction(name: "frag")
    renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    renderPipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
    renderPipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
    renderPipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
    do {
        renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
    }
    catch {
      print("Failed to create render pipeline state")
    }

    // Create device buffers
    let datasize = MemoryLayout<float4>.size * nbodies
    d_positions0 = device.makeBuffer(length: datasize, options: .storageModeManaged)
    d_positions1 = device.makeBuffer(length: datasize, options: .storageModeManaged)
    d_velocities = device.makeBuffer(length: datasize, options: .storageModeManaged)

    // Copy data from previous device
    if retainBodies {
      if h_positions != nil {
        memcpy(d_positions0!.contents(), h_positions!, datasize)
        d_positions0?.didModifyRange(0..<datasize)
      }
      if h_velocities != nil {
        memcpy(d_velocities!.contents(), h_velocities!, datasize)
        d_velocities?.didModifyRange(0..<datasize)
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
    d_computeParams = device.makeBuffer(bytes: &h_computeParams, length: MemoryLayout<ComputeParams>.size, options: .cpuCacheModeWriteCombined)

    // Initialise view-projection matrices
    let projectionMatrix = GLKMatrix4MakePerspective(1.0, Float(WIDTH)/Float(HEIGHT), 0.1, 50.0)
    var vpMatrix = GLKMatrix4Identity
    vpMatrix = GLKMatrix4Translate(vpMatrix, 0.0, 0.0, -1.5)
    vpMatrix = GLKMatrix4Multiply(projectionMatrix, vpMatrix)

    var eyePosition = float3(0, 0, 1.5)

    let renderParamsSize = MemoryLayout<matrix_float4x4>.size + MemoryLayout<float4>.size
    d_renderParams = device.makeBuffer(length: renderParamsSize, options: .cpuCacheModeWriteCombined)
    memcpy(d_renderParams.contents(), &vpMatrix.m, MemoryLayout<matrix_float4x4>.size)
    memcpy(d_renderParams.contents() + MemoryLayout<matrix_float4x4>.size, &eyePosition, MemoryLayout<float3>.size)
  }

  override func keyDown(with theEvent: NSEvent) {
    switch theEvent.keyCode {
    case 2:
      // Select next device
      deviceIndex += 1
      if deviceIndex >= MTLCopyAllDevices().count {
        deviceIndex = 0
      }
      initMetal(retainBodies: true)
    case 15:
      initBodies()
    case 12:
      exit(0)
    case 27:
      if nbodies > MINBODIES {
        nbodies /= 2
        initMetal(retainBodies: false)
        initBodies()
      }
    case 24:
      if theEvent.modifierFlags.contains(NSEvent.ModifierFlags.shift) {
        if nbodies < MAXBODIES {
          nbodies *= 2
          initMetal(retainBodies: false)
          initBodies()
        }
      }
    default:
      super.keyDown(with: theEvent)
    }
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
  }
}
