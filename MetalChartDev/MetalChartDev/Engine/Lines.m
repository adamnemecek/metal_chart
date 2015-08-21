//
//  PolyLines.m
//  MetalChartDev
//
//  Created by Mori Keisuke on 2015/08/06.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import "Lines.h"

@interface Line()

- (instancetype _Null_unspecified)initWithEngine:(LineEngine * _Nonnull)engine
										  series:(id<Series> _Nonnull)series
;

- (id<MTLRenderPipelineState> _Nonnull)renderPipelineStateWithProjection:(UniformProjection * _Nonnull)projection;
- (NSUInteger)vertexCountWithCount:(NSUInteger)count;
- (id<MTLBuffer> _Nullable)indexBuffer;
- (NSString *)vertexFunctionName;
- (NSString *)fragmentFunctionName;

@end



@interface OrderedSeparatedLine()

@property (strong, nonatomic) OrderedSeries * _Nonnull orderedSeries;

@end



@interface OrderedPolyLine()

@property (strong, nonatomic) OrderedSeries * _Nonnull orderedSeries;

@end



@interface IndexedPolyLine()

@property (strong, nonatomic) IndexedSeries * _Nonnull indexedSeries;

@end

@implementation Line

- (instancetype)initWithEngine:(LineEngine *)engine
						series:(id<Series> _Nonnull)series
{
    self = [super init];
    if(self) {
		DeviceResource *resource = engine.resource;
		_series = series;
		_engine = engine;
		_attributes = [[UniformLineAttributes alloc] initWithResource:resource];
    }
    return self;
}

- (id<MTLRenderPipelineState>)renderPipelineStateWithProjection:(UniformProjection *)projection
{
	return [_engine pipelineStateWithProjection:projection vertFunc:[self vertexFunctionName] fragFunc:[self fragmentFunctionName]];
}

- (id<MTLDepthStencilState>)depthState
{
	return _attributes.enableOverlay ? _engine.depthState_noDepth : _engine.depthState_writeDepth;
}

- (NSString *)vertexFunctionName
{
	abort();
}

- (NSString *)fragmentFunctionName
{
	return _attributes.enableOverlay ? @"LineEngineFragment_NoDepth" : @"LineEngineFragment_WriteDepth";
}

- (NSUInteger)vertexCountWithCount:(NSUInteger)count
{
	return 0;
}

- (id<MTLBuffer>)indexBuffer { return nil; }

- (void)encodeWith:(id<MTLRenderCommandEncoder>)encoder
		projection:(UniformProjection *)projection
{
	id<MTLRenderPipelineState> renderState = [self renderPipelineStateWithProjection:projection];
	id<MTLDepthStencilState> depthState = [self depthState];
	[encoder pushDebugGroup:@"DrawLine"];
	[encoder setRenderPipelineState:renderState];
	[encoder setDepthStencilState:depthState];
	
	const CGSize ps = projection.physicalSize;
	const RectPadding pr = projection.padding;
	const CGFloat scale = projection.screenScale;
	if(projection.enableScissor) {
		MTLScissorRect rect = {pr.left*scale, pr.top*scale, (ps.width-(pr.left+pr.right))*scale, (ps.height-(pr.bottom+pr.top))*scale};
		[encoder setScissorRect:rect];
	} else {
		MTLScissorRect rect = {0, 0, ps.width * scale, ps.height * scale};
		[encoder setScissorRect:rect];
	}
	
	NSUInteger idx = 0;
	id<MTLBuffer> vertexBuffer = [_series vertexBuffer];
	id<MTLBuffer> indexBuffer = [self indexBuffer];
	UniformLineAttributes *attributes = _attributes;
	UniformSeriesInfo *info = _series.info;

	[encoder setVertexBuffer:vertexBuffer offset:0 atIndex:idx++];
	if( indexBuffer ) {
		[encoder setVertexBuffer:indexBuffer offset:0 atIndex:idx++];
	}
	[encoder setVertexBuffer:projection.buffer offset:0 atIndex:idx++];
	[encoder setVertexBuffer:attributes.buffer offset:0 atIndex:idx++];
	[encoder setVertexBuffer:info.buffer offset:0 atIndex:idx++];
	
	[encoder setFragmentBuffer:projection.buffer offset:0 atIndex:0];
	[encoder setFragmentBuffer:attributes.buffer offset:0 atIndex:1];
	
//	const NSUInteger count = 6 * MAX(0, ((NSInteger)(separated ? (info.count/2) : info.count-1))); // 折れ線でない場合、線数は半分になる、それ以外は-1.４点を結んだ場合を想像するとわかる. この線数に６倍すると頂点数.
	NSUInteger count = [self vertexCountWithCount:info.count];
	if(count > 0) {
		const NSUInteger offset = 6 * (info.offset); // オフセットは折れ線かそうでないかに関係なく奇数を指定できると使いかたに幅が持たせられる.
		[encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:offset vertexCount:count];
	}
	
	[encoder popDebugGroup];
}

- (void)setSampleAttributes
{
	UniformLineAttributes *attributes = self.attributes;
	[attributes setColorWithRed:0.3 green:0.6 blue:0.8 alpha:0.5];
	[attributes setWidth:3];
	attributes.enableOverlay = NO;
}

@end

@implementation OrderedSeparatedLine

- (instancetype)initWithEngine:(LineEngine *)engine
				orderedSeries:(OrderedSeries * _Nonnull)series
{
	self = [super initWithEngine:engine series:series];
	if(self) {
		_orderedSeries = series;
	}
	return self;
}

- (NSUInteger)vertexCountWithCount:(NSUInteger)count
{
	return 6 * MAX(0, ((NSInteger)(count/2)));
}

- (NSString *)vertexFunctionName { return @"SeparatedLineEngineVertexOrdered"; }

@end

@implementation PolyLine

- (NSUInteger)vertexCountWithCount:(NSUInteger)count
{
	return 6 * MAX(0, ((NSInteger)(count-1)));
}

@end

@implementation OrderedPolyLine

- (instancetype)initWithEngine:(LineEngine *)engine
				 orderedSeries:(OrderedSeries * _Nonnull)series
{
	self = [super initWithEngine:engine series:series];
	if(self) {
		_orderedSeries = series;
	}
	return self;
}

- (void)setSampleData
{
	VertexBuffer *vertices = _orderedSeries.vertices;
	const NSUInteger vCount = vertices.capacity;
	for(int i = 0; i < vCount; ++i) {
		vertex_buffer *v = [vertices bufferAtIndex:i];
		const float range = 0.5;
		v->position.x = ((2 * ((i  ) % 2)) - 1) * range;
		v->position.y = ((2 * ((i/2) % 2)) - 1) * range;
	}
	self.series.info.offset = 0;
	
	[self setSampleAttributes];
}

static double gaussian() {
	const double u1 = (double)arc4random() / UINT32_MAX;
	const double u2 = (double)arc4random() / UINT32_MAX;
	const double f1 = sqrt(-2 * log(u1));
	const double f2 = 2 * M_PI * u2;
	return f1 * sin(f2);
}

- (void)appendSampleData:(NSUInteger)count
		  maxVertexCount:(NSUInteger)maxCount
			  onGenerate:(void (^ _Nullable)(float, float))block
{
	VertexBuffer *vertices = _orderedSeries.vertices;
	const NSUInteger capacity = vertices.capacity;
	const NSUInteger idx_start = self.series.info.offset + self.series.info.count;
	const NSUInteger idx_end = idx_start + count;
	for(NSUInteger i = 0; i < count; ++i) {
		vertex_buffer *v = [vertices bufferAtIndex:(idx_start+i)%capacity];
		const float x = idx_start + i;
		const float y = gaussian() * 0.5;
		v->position.x = x;
		v->position.y = y;
		if(block) {
			block(x, y);
		}
	}
	const NSUInteger vCount = MIN(capacity, MIN(maxCount, idx_end));
	self.series.info.count = vCount;
	self.series.info.offset = idx_end - vCount;
}

- (NSString *)vertexFunctionName { return @"PolyLineEngineVertexOrdered"; }

@end

@implementation IndexedPolyLine

- (instancetype)initWithEngine:(LineEngine *)engine
				 indexedSeries:(IndexedSeries * _Nonnull)series
{
	self = [super initWithEngine:engine series:series];
	if(self) {
		_indexedSeries = series;
	}
	return self;
}

- (id<MTLBuffer>)indexBuffer
{
	return _indexedSeries.indices.buffer;
}

- (NSString *)vertexFunctionName { return @"PolyLineEngineVertexIndexed"; }

@end

@implementation Axis

- (instancetype)initWithEngine:(LineEngine *)engine
{
    self = [super init];
    if(self) {
        _engine = engine;
        _uniform = [[UniformAxis alloc] initWithResource:engine.resource];
    }
    return self;
}

- (id<MTLRenderPipelineState>)renderPipelineStateWithProjection:(UniformProjection *)projection
{
    return [_engine pipelineStateWithProjection:projection
                                       vertFunc:@"AxisVertex"
                                       fragFunc:@"AxisFragment"];
}

- (void)encodeWith:(id<MTLRenderCommandEncoder>)encoder
        projection:(UniformProjection *)projection
{
    id<MTLRenderPipelineState> renderState = [self renderPipelineStateWithProjection:projection];
    id<MTLDepthStencilState> depthState = _engine.depthState_noDepth;
    [encoder pushDebugGroup:@"DrawAxis"];
    [encoder setRenderPipelineState:renderState];
    [encoder setDepthStencilState:depthState];
    
    const CGSize ps = projection.physicalSize;
    const CGFloat scale = projection.screenScale;
    MTLScissorRect rect = {0, 0, ps.width * scale, ps.height * scale};
    [encoder setScissorRect:rect];
    
    [encoder setVertexBuffer:_uniform.axisBuffer offset:0 atIndex:0];
    [encoder setVertexBuffer:_uniform.attributeBuffer offset:0 atIndex:1];
    [encoder setVertexBuffer:projection.buffer offset:0 atIndex:2];
    
    [encoder setFragmentBuffer:_uniform.attributeBuffer offset:0 atIndex:0];
	[encoder setFragmentBuffer:projection.buffer offset:0 atIndex:1];
    
    const NSUInteger lineCount = (1 + ((1+_uniform.minorTicksPerMajor) * _uniform.maxMajorTicks));
    const NSUInteger vertCount = 6 * lineCount;
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:vertCount];
    
    [encoder popDebugGroup];
}

@end

