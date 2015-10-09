//
//  shaders.metal
//  NBody-Metal
//
//  Created by James Price on 09/10/2015.
//  Copyright © 2015 James Price. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void step(device float4* positions [[buffer(0)]],
                        uint    i         [[thread_position_in_grid]])
{
  positions[i][0] += 0.001;
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
