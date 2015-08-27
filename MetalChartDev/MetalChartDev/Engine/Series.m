//
//  Series.m
//  MetalChartDev
//
//  Created by Mori Keisuke on 2015/08/11.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import "Series.h"

@interface OrderedSeries()

@end

@implementation OrderedSeries

- (instancetype)initWithResource:(DeviceResource *)resource
				  vertexCapacity:(NSUInteger)vertCapacity
{
	self = [super init];
	if(self) {
		_vertices = [[VertexBuffer alloc] initWithResource:resource capacity:vertCapacity];
		_info = [[UniformSeriesInfo alloc] initWithResource:resource];
		
		[_info info]->vertex_capacity = (uint32_t)vertCapacity;
	}
	return self;
}

- (id<MTLBuffer>)vertexBuffer { return _vertices.buffer; }

- (void)addPoint:(CGPoint)point
{
	[self addPoint:point maxCount:_vertices.capacity];
}

- (void)addPoint:(CGPoint)point maxCount:(NSUInteger)max
{
	const NSUInteger count = _info.count;
	const NSUInteger idx = count + _info.offset;
	[_vertices bufferAtIndex:idx]->position = vector2((float)point.x, (float)point.y);
	if(0 < max && max <= count) {
		_info.offset += 1;
	} else {
		_info.count += 1;
	}
}

@end

@implementation IndexedSeries


- (instancetype)initWithResource:(DeviceResource *)resource
				  vertexCapacity:(NSUInteger)vertCapacity
				   indexCapacity:(NSUInteger)idxCapacity
{
	self = [super init];
	if(self) {
		_vertices = [[VertexBuffer alloc] initWithResource:resource capacity:vertCapacity];
		_indices = [[IndexBuffer alloc] initWithResource:resource capacity:idxCapacity];
		_info = [[UniformSeriesInfo alloc] initWithResource:resource];
		
		[_info info]->vertex_capacity = (uint32_t)vertCapacity;
		[_info info]->index_capacity = (uint32_t)idxCapacity;
	}
	return self;
}

- (id<MTLBuffer>)vertexBuffer { return _vertices.buffer; }

@end

