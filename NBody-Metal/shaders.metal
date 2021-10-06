//
//  shaders.metal
//  NBody-Metal
//
//  Created by James Price on 09/10/2015.
//  Copyright © 2015 James Price. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#define GROUPSIZE 64 // must be same as GROUPSIZE in NBodyViewController.swift

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
  float  dist   = fast::rsqrt(distSq);
  float  coeff  = jpos.w * (dist*dist*dist);
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

  threadgroup float4 scratch[GROUPSIZE];

  // Compute force
  float4 force = 0.f;
  for (uint j = 0; j < params.nbodies; j+=GROUPSIZE)
  {
    threadgroup_barrier(mem_flags::mem_threadgroup);
    scratch[l] = positionsIn[j + l];
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint k = 0; k < GROUPSIZE;)
    {
      force += computeForce(ipos, scratch[k++], params.softening);
      force += computeForce(ipos, scratch[k++], params.softening);
      force += computeForce(ipos, scratch[k++], params.softening);
      force += computeForce(ipos, scratch[k++], params.softening);
    }
  }

  // Update velocity
  float4 velocity = velocities[i];
  velocity       += force * params.delta;
  velocities[i]   = velocity;

  // Update position
  positionsOut[i] = ipos + velocity*params.delta;
}

#define POINT_SCALE 20.f
#define SIGHT_RANGE  3.f

struct VertexOut
{
  float4 position  [[position]];
  float  pointSize [[point_size]];
  float3 color [[user(locn0)]];
};

struct RenderParams
{
  float4x4 vpMatrix;
  float3   eyePosition;
};

vertex VertexOut vert(const device float4*      vertices [[buffer(0)]],
                      const device RenderParams &params  [[buffer(1)]],
                                   unsigned int vid      [[vertex_id]])
{
  VertexOut out;

  float4 pos = vertices[vid];

  out.position = params.vpMatrix * pos;

  float dist = distance(pos.xyz, params.eyePosition);
  float size = POINT_SCALE * (1.f - (dist / SIGHT_RANGE));
  out.pointSize = max(size, 0.f);

  if (vid % 2) {
    out.color = float3(0.4f, 0.4f, 1.f);
  } else {
    out.color = float3(1.f, 0.4f, 0.4f);
  }

  return out;
}

struct FragIn {
  float3 color [[user(locn0)]];
};

fragment half4 frag(float2 pointCoord [[point_coord]], FragIn inputs [[stage_in]])
{
  float dist = distance(float2(0.5f), pointCoord);
  if (dist > 0.5)
    discard_fragment();

  float intensity = (1.f - (dist*2.f)) * 0.6f;
  float3 c = inputs.color * intensity;
  return half4(c.r, c.g, c.b, 1.f);
}
