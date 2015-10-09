//
//  shaders.metal
//  NBody-Metal
//
//  Created by James Price on 09/10/2015.
//  Copyright © 2015 James Price. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#define WGSIZE 64

struct Params
{
  uint  nbodies;
  float delta;
  float softening;
};

float4 computeForce(float4 ipos, float4 jpos, float softening);

float4 computeForce(float4 ipos, float4 jpos, float softening)
{
  float4 d      = jpos - ipos;
         d.w    = 0;
  float  distSq = d.x*d.x + d.y*d.y + d.z*d.z + softening*softening;
  float  dist   = sqrt(distSq);
  float  coeff  = jpos.w / (dist*dist*dist);
  return coeff * d;
}

kernel void step(const device   float4* positionsIn  [[buffer(0)]],
                       device   float4* positionsOut [[buffer(1)]],
                       device   float4* velocities   [[buffer(2)]],
                       constant Params  &params      [[buffer(3)]],
                                uint    i            [[thread_position_in_grid]],
                                uint    l            [[thread_position_in_threadgroup]])
{
  float4 ipos = positionsIn[i];

  threadgroup float4 scratch[WGSIZE];

  // Compute force
  float4 force = 0.f;
  for (uint j = 0; j < params.nbodies; j+=WGSIZE)
  {
    threadgroup_barrier(mem_flags::mem_threadgroup);
    scratch[l] = positionsIn[j + l];
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint k = 0; k < WGSIZE; k++)
    {
      force += computeForce(ipos, scratch[k], params.softening);
    }
  }

  // Update velocity
  float4 velocity = velocities[i];
  velocity       += force * params.delta;
  velocities[i]   = velocity;

  // Update position
  positionsOut[i] = ipos + velocity*params.delta;
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
