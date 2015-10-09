//
//  shaders.metal
//  NBody-Metal
//
//  Created by James Price on 09/10/2015.
//  Copyright © 2015 James Price. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

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
                       constant uint    &nbodies     [[buffer(3)]],
                                uint    i            [[thread_position_in_grid]])
{
  float softening = 0.1;
  float delta = 0.0001;

  float4 ipos = positionsIn[i];

  float4 force = 0.f;
  for (uint j = 0; j < nbodies; j++)
  {
    force += computeForce(ipos, positionsIn[j], softening);
  }

  // Update velocity
  float4 velocity = velocities[i];
  velocity       += force * delta;
  velocities[i]   = velocity;

  // Update position
  positionsOut[i] = ipos + velocity*delta;
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
