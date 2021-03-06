//
//  LineEngineShaderAux.metal
//  FMChart
//
//  Created by Keisuke Mori on 2015/08/17.
//  Copyright © 2015 Keisuke Mori. All rights reserved.
//

// ちなみに、このファイル内のshaderではbranch命令が0である(stdlibに含まれてなければ)

#include "LineEngineShader.h"

struct out_vertex_axis {
	float4 position_ndc [[ position ]];
	float2 position_scaled;
	float  l_scaled  [[ flat ]];
	float  scale	 [[ flat ]];
	float  dropped   [[ flat ]];
	uint   attr_idx  [[ flat ]];
};

struct out_vertex_grid {
	float4 position_ndc [[ position ]];
	float2 position_scaled;
	float  l_scaled  [[ flat ]];
	float  scale	 [[ flat ]];
	float  depth	 [[ flat ]];
	float  dropped   [[ flat ]];
};

inline float2 axis_mid_pos( const bool is_axis, constant uniform_axis_configuration& axis, constant uniform_projection_cart2d& proj )
{
	const uchar idx = axis.dimIndex;
	const uchar idx_orth = idx ^ 0x01;
	float2 v = - proj.value_offset;
	// tick_value = tick_anchor_value + (n * tick_interval_major) >= minとなる最小の整数nを求める.
	const float v_min = (v - proj.value_scale)[idx];
	const float interval = axis.tick_interval_major;
	const float tick_anchor = axis.tick_anchor_value;
	
	const float n = ceil((v_min - tick_anchor) / interval);
	const float tick_value = tick_anchor + (n * interval);
	v[idx] = ((is_axis) * v[idx]) + ((!is_axis) * tick_value);
	const float axis_ndc = axis.axis_anchor_value_ndc;
	const bool in_ndc_range = (-1 <= axis_ndc) * (axis_ndc <= 1);
	const float mid_data = semi_ndc_to_data(float2(axis_ndc, axis_ndc), proj)[idx_orth]; // 情報として片次元たりてないけど気にしない.
	v[idx_orth] = ((in_ndc_range) * mid_data) + ((!in_ndc_range) * axis.axis_anchor_value_data);
	return v;
}

inline float2 axis_dir_vec( const uchar dimIndex, const bool is_axis )
{
	const uchar idx = dimIndex ^ (!is_axis);
	float2 v(0, 0);
	v[idx] = 1;
	return v;
}

inline float2 tick_iter_vec( constant uniform_axis_configuration& axis, const bool is_axis ) {
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

inline float get_iter_coef(const uchar type, const uint iter_idx, const uchar minor_ticks_per_major)
{
	// ここで問題となるのは、axis_valueと対照tickとの距離、をfreqで割った値、となる.
	const float denom = (1 + ((type == 2) * (minor_ticks_per_major - 1)));
	const float coef_step = iter_idx / denom;
	return coef_step - ((denom-1)/denom); // minorTickのみ係数が負(基準点よりも小さい座標)となる事がありえる。
}

inline bool is_dropped(const float2 mid, const uchar dimIndex, constant uniform_projection_cart2d& proj)
{
	const float a = (mid - (-proj.value_scale - proj.value_offset))[dimIndex]; // mid - min
	const float b = ((+proj.value_scale - proj.value_offset) - mid)[dimIndex]; // max - mid
	return !((a >= -0.0f) && (b >= -0.0f));
}

vertex out_vertex_axis AxisVertex(
								  constant uniform_axis_configuration& axis [[ buffer(0) ]],
								  constant uniform_axis_attributes *attr_ptr [[ buffer(1) ]],
								  constant uniform_projection_cart2d& proj [[ buffer(2) ]],
								  uint v_id [[ vertex_id ]]
								  )
{
	const uint vid = v_id / 6;
	const uchar spec = v_id % 6;
	
	const uchar max_major_ticks = axis.max_major_ticks;
	const uchar dimIndex = axis.dimIndex;
	const uchar type = get_type(vid, max_major_ticks);
	const uint  iter_idx = get_iter_idx(vid, max_major_ticks);
	constant uniform_axis_attributes& attr = attr_ptr[type];
	
	const bool is_axis = (type == 0);
	const float2 axis_mid = axis_mid_pos(is_axis, axis, proj);
	const float2 mid = axis_mid + (get_iter_coef(type, iter_idx, axis.minor_ticks_per_major) * tick_iter_vec(axis, is_axis));
	const float2 dir = axis_dir_vec(dimIndex, is_axis);
	const float2 physical_size = proj.physical_size;
	const float4 padding = proj.rect_padding;
	const float2 plot_size = physical_size - (padding.xy + padding.zw);
	const float2 modifier = (attr.line_length * max(1.0f, (type == 0) * plot_size[dimIndex])) * attr.length_mod;
	float2 start = data_to_ndc(mid - dir, proj);
	float2 end = data_to_ndc(mid + dir, proj);
	
	modify_length(start, end, modifier, physical_size);
	
	out_vertex_axis out = LineDashVertexCore<out_vertex_axis>(start, end, spec, attr.width, proj);
	out.attr_idx = uint(type);
	out.dropped = is_dropped(mid, dimIndex, proj);
	
	return out;
}

fragment float4 AxisFragment(
							 const out_vertex_axis                input [[ stage_in ]],
							 constant uniform_axis_attributes* attr_ptr [[ buffer(0) ]],
							 constant uniform_projection_cart2d&   proj [[ buffer(1) ]]
							 )
{
	const uint index = input.attr_idx;
	constant uniform_axis_attributes& attr = attr_ptr[index];
	float4 color = (!input.dropped) * attr.color;
	const float ratio = LineDashFragmentCore(input);
	color.a *= ratio;
	
	return color;
}

inline float2 grid_mid_pos( uint vid, constant uniform_grid_configuration& grid, constant uniform_projection_cart2d& proj )
{
	const uchar idx = grid.dimIndex;
	float2 v = - proj.value_offset;
	// tick_value = tick_anchor_value + (n * tick_interval_major) >= minとなる最小の整数nを求める.
	const float v_min = (v - proj.value_scale)[idx];
	const float interval = grid.interval;
	const float grid_anchor = grid.anchor_value;
	
	const float n = ceil((v_min - grid_anchor) / interval);
	const float grid_value = grid_anchor + ((n+vid) * interval);
	v[idx] = grid_value;
	return v;
}

inline float2 grid_vec_dir( constant uniform_grid_configuration& grid, constant uniform_projection_cart2d& proj )
{
	const uchar idx = grid.dimIndex;
	float2 v = proj.value_scale;
	v[idx] = 0;
	return v;
}

vertex out_vertex_grid GridVertex(
								  constant uniform_grid_configuration&    conf [[ buffer(0) ]],
								  constant uniform_grid_attributes&       attr [[ buffer(1) ]],
								  constant uniform_projection_cart2d&	  proj [[ buffer(2) ]],
								  uint v_id [[ vertex_id ]]
								  )
{
	const uint vid = v_id / 6;
	const uchar spec = v_id % 6;
	
	const float2 mid_pos_data = grid_mid_pos(vid, conf, proj);
	const float2 vec_dir_data = grid_vec_dir(conf, proj) * 2;
	const float4 pd = proj.rect_padding;
	const float l = (attr.length_repeat + attr.length_space + .5) * attr.width;
	const float2 l_data = l * float2(4, 4) * (proj.value_scale) / (proj.physical_size - (pd.xy+pd.wz));
	const float2 diff_data = - normalize(vec_dir_data) * (attr.length_repeat > 0 ? fmod(mid_pos_data, l_data) : float2(0, 0));
	
	const float2 start = data_to_ndc(mid_pos_data + diff_data - vec_dir_data, proj);
	const float2 end = data_to_ndc(mid_pos_data + diff_data + vec_dir_data, proj);
	out_vertex_grid out = LineDashVertexCore<out_vertex_grid>(start, end, spec, attr.width, proj);
	out.dropped = is_dropped(mid_pos_data, conf.dimIndex, proj);
	
	return out;
}


fragment out_fragment_depthGreater GridFragment(
												const out_vertex_grid			      in   [[ stage_in ]],
												constant uniform_grid_configuration&  conf [[ buffer(0) ]],
												constant uniform_grid_attributes&     attr [[ buffer(1) ]],
												constant uniform_projection_cart2d&	  proj [[ buffer(2) ]])
{
	const float ratio = min(LineDashFragmentCore(in), LineDashFragmentExtra(in, attr));
	out_fragment_depthGreater out;
	out.color = (!in.dropped) * attr.color;
	out.color.a *= ratio;
	out.depth = conf.depth;
	
	return out;
}
