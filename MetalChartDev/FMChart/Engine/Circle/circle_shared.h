//
//  circle_shared.h
//  FMChart
//
//  Created by Keisuke Mori on 2015/11/18.
//  Copyright © 2015 Keisuke Mori. All rights reserved.
//

#ifndef circle_shared_h
#define circle_shared_h

#include <simd/simd.h>

#ifdef __cplusplus

using namespace simd;

#endif

/**
 * see FMUniformArcConfiguration (CircleBuffers.h).
 */

struct arc_conf {
	float  radius_inner;
	float  radius_outer;
	float  radian_offset;
	float  radian_scale;
};

/**
 * see FMUniformArcAttributes (CircleBuffers.h).
 */

struct arc_attr {
	vector_float4 color;
	float radius_inner;
	float radius_outer;
};

#ifdef __OBJC__

typedef struct arc_conf uniform_arc_configuration;

typedef struct arc_attr uniform_arc_attributes ;

#endif

#endif /* circle_shared_h */
