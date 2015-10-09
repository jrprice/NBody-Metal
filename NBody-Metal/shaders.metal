//
//  shaders.metal
//  NBody-Metal
//
//  Created by James Price on 09/10/2015.
//  Copyright © 2015 James Price. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void step(device packed_float3* positions [[buffer(0)]],
                        uint           i         [[thread_position_in_grid]])
{
  positions[0][0] += 0.001;
}

vertex float4 vert(const device packed_float3* vertices [[buffer(0)]],
                                unsigned int   vid      [[vertex_id]])
{
  return float4(vertices[vid], 1.0);
}

fragment half4 frag()
{
  return half4(1.0);
}
