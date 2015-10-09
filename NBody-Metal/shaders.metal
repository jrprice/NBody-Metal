//
//  shaders.metal
//  NBody-Metal
//
//  Created by James Price on 09/10/2015.
//  Copyright © 2015 James Price. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void step(const device float4* positionsIn  [[buffer(0)]],
                       device float4* positionsOut [[buffer(1)]],
                       device float4* velocities   [[buffer(2)]],
                        uint    i         [[thread_position_in_grid]])
{
  float4 pos = positionsIn[i];
  pos[0] += 0.001;
  positionsOut[i] = pos;
}

vertex float4 vert(const device float4*      vertices [[buffer(0)]],
                                unsigned int vid      [[vertex_id]])
{
  return vertices[vid];
}

fragment half4 frag()
{
  return half4(1.0);
}
