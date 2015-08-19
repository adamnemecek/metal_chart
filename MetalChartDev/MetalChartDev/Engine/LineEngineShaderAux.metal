//
//  LineEngineShaderAux.metal
//  MetalChartDev
//
//  Created by Keisuke Mori on 2015/08/17.
//  Copyright © 2015年 freaks. All rights reserved.
//

// ちなみに、このファイル内のshaderではbranch命令が0である(stdlibに含まれてなければ)

#include <metal_stdlib>
#include "LineEngineShader.h"

using namespace metal;

struct uniform_axis {
    float  axis_anchor_value;
    float  tick_anchor_value;
	float  tick_interval_major;
    
    uchar  dimIndex;
    uchar  minor_ticks_per_major;
    uchar  max_major_ticks;
};

struct uniform_axis_attributes {
	float4 color;
	float2 length_mod;
	float  line_length;
	float  width;
};

struct out_vertex_axis {
    float4 position [[ position ]];
    float2 mid_pos  [[ flat ]];
    float2 vec_dir  [[ flat ]];
    float2 pos;
    float  coef;
    uchar  index    [[ flat ]];
};

inline float2 axis_mid_pos( const bool is_axis, constant uniform_axis& axis, constant uniform_projection& proj )
{
	const uchar idx = axis.dimIndex;
	const uchar idx_orth = idx ^ 0x01;
	float2 v = proj.value_offset;
	// tick_value = tick_anchor_value + (n * tick_interval_major) >= minとなる最小の整数nを求める.
	const float min = (v - proj.value_scale)[idx];
	const float interval = axis.tick_interval_major;
	const float tick_anchor = axis.tick_anchor_value;
	
	const float n = ceil((min - tick_anchor) / interval);
	const float tick_value = tick_anchor + (n * interval);
	v[idx] = ((is_axis) * v[idx]) + ((!is_axis) * tick_value);
	v[idx_orth] = axis.axis_anchor_value;
	return v;
}

inline float2 axis_dir_vec( const uchar dimIndex, const bool is_axis )
{
	const uchar idx = dimIndex ^ (!is_axis);
	float2 v(0, 0);
	v[idx] = 1;
	return v;
}

inline float2 tick_iter_vec( constant uniform_axis& axis, const bool is_axis ) {
	const uchar idx = axis.dimIndex;
	float2 v(0, 0);
	v[idx] = axis.tick_interval_major * (!is_axis); // 軸の場合は移動0.
	return v;
}

inline uchar get_type(const uint vid, const uchar max_major_ticks) {
	uchar type = 0;
	type += (vid > 0);
	type += (vid > max_major_ticks);
	return type;
}

// 基本的なロジックはget_typeと等価.
inline uint get_iter_idx(const uint vid, const uchar max_major_ticks) {
	uint idx = vid;
	idx -= (vid > 0);
	idx -= ((vid > max_major_ticks) * (max_major_ticks));
	return idx;
}

inline float get_iter_coef(const uchar type, const uint iter_idx, const float2 mid_pos, constant uniform_axis& axis, constant uniform_projection& proj)
{
	const uchar dimIndex = axis.dimIndex;
	// ここで問題となるのは、axis_valueと対照tickとの距離、をfreqで割った値、となる.
	const uchar denom = (1 + ((type == 2) * (axis.minor_ticks_per_major - 1)));
	const float diff = (mid_pos - (proj.value_offset - proj.value_scale))[dimIndex];
	const float coef_multiplied = (iter_idx) - (diff * denom / axis.tick_interval_major);
	const float coef_step = ceil(coef_multiplied) / (float)(denom);
	return coef_step;
}

vertex out_vertex_axis AxisVertex(
								  constant uniform_axis& axis [[ buffer(0) ]],
								  constant uniform_axis_attributes *attr_ptr [[ buffer(1) ]],
								  constant uniform_projection& proj [[ buffer(2) ]],
								  uint v_id [[ vertex_id ]]
								  )
{
	const uint vid = v_id / 6;
	const uchar spec = v_id % 6;
    
	const uchar max_major_ticks = axis.max_major_ticks;
	const uchar type = get_type(vid, max_major_ticks);
	const uint  iter_idx = get_iter_idx(vid, max_major_ticks);
	constant uniform_axis_attributes& attr = attr_ptr[type];
	
	const bool is_axis = (type == 0);
	const float2 axis_mid = axis_mid_pos(is_axis, axis, proj);
	const float2 mid = axis_mid + (get_iter_coef(type, iter_idx, axis_mid, axis, proj) * tick_iter_vec(axis, is_axis));
	const float2 dir = axis_dir_vec(axis.dimIndex, is_axis);
	const float2 modifier = attr.line_length * attr.length_mod;
	float2 start = adjustPoint(mid - dir, proj);
	float2 end = adjustPoint(mid + dir, proj);
	
	const float2 physical_size = proj.physical_size;
	modify_length(start, end, modifier, physical_size);
	
	out_vertex_axis out = LineEngineVertexCore<out_vertex_axis>(start, end, spec, attr.width, physical_size);
	out.index = type;
	
	return out;
}

fragment float4 AxisFragment(
							 const out_vertex_axis input [[ stage_in ]],
							 constant uniform_axis_attributes *attr_ptr [[ buffer(0) ]],
							 constant uniform_projection& proj [[ buffer(1) ]]
							 )
{
	constant uniform_axis_attributes& attr = attr_ptr[input.index];
	const out_frag_core core = LineEngineFragmentCore_ratio(input, proj, attr.width);
	float4 color = attr.color;
	color.a *= saturate((!core.is_same_dir) + core.ratio );
	
	return color;

}