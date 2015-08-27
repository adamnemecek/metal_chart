//
//  Rects.m
//  MetalChartDev
//
//  Created by Mori Keisuke on 2015/08/26.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import "Rects.h"
#import <Metal/Metal.h>
#import "Engine.h"
#import "Buffers.h"
#import "RectBuffers.h"
#import "Series.h"

@implementation PlotRect

- (instancetype)initWithEngine:(Engine *)engine
{
    self = [super init];
    if(self) {
        _engine = engine;
        DeviceResource *res = engine.resource;
        _rect = [[UniformPlotRect alloc] initWithResource:res];
    }
    return self;
}

- (void)encodeWith:(id<MTLRenderCommandEncoder>)encoder projection:(UniformProjection *)projection
{
    id<MTLRenderPipelineState> renderState = [_engine pipelineStateWithProjection:projection vertFunc:@"PlotRect_Vertex" fragFunc:@"PlotRect_Fragment"];
    id<MTLDepthStencilState> depthState = _engine.depthState_noDepth;
    [encoder pushDebugGroup:@"DrawPlotRect"];
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
    
    id<MTLBuffer> const rectBuffer = _rect.buffer;
    id<MTLBuffer> const projBuffer = projection.buffer;
    [encoder setVertexBuffer:rectBuffer offset:0 atIndex:0];
    [encoder setVertexBuffer:projBuffer offset:0 atIndex:1];
    [encoder setFragmentBuffer:rectBuffer offset:0 atIndex:0];
    [encoder setFragmentBuffer:projBuffer offset:0 atIndex:1];
    
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    
    [encoder popDebugGroup];
}

@end

@interface Bar()

- (instancetype _Null_unspecified)initWithEngine:(Engine * _Nonnull)engine
                                          series:(id<Series> _Nonnull)series
;

- (id<MTLRenderPipelineState> _Nonnull)renderPipelineStateWithProjection:(UniformProjection * _Nonnull)projection;
- (NSUInteger)vertexCountWithCount:(NSUInteger)count;
- (NSUInteger)vertexOffsetWithOffset:(NSUInteger)offset;
- (id<MTLBuffer> _Nullable)indexBuffer;
- (NSString * _Nonnull)vertexFunctionName;

@end

@implementation Bar

- (instancetype)initWithEngine:(Engine *)engine series:(id<Series>)series
{
    self = [super init];
    if(self) {
        _engine = engine;
        _series = series;
        DeviceResource *res = engine.resource;
        _bar = [[UniformBar alloc] initWithResource:res];
    }
    return self;
}

- (void)encodeWith:(id<MTLRenderCommandEncoder>)encoder
        projection:(UniformProjection *)projection
{
    id<MTLRenderPipelineState> renderState = [self renderPipelineStateWithProjection:projection];
    id<MTLDepthStencilState> depthState = _engine.depthState_noDepth;
    [encoder pushDebugGroup:@"DrawBar"];
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
    
    id<MTLBuffer> const vertexBuffer = [_series vertexBuffer];
    id<MTLBuffer> const indexBuffer = [self indexBuffer];
    id<MTLBuffer> const barBuffer = _bar.buffer;
    id<MTLBuffer> const projBuffer = projection.buffer;
    NSUInteger idx = 0;
    [encoder setVertexBuffer:vertexBuffer offset:0 atIndex:idx++];
    if(indexBuffer) {
        [encoder setVertexBuffer:indexBuffer offset:0 atIndex:idx++];
    }
    [encoder setVertexBuffer:barBuffer offset:0 atIndex:idx++];
    [encoder setVertexBuffer:projBuffer offset:0 atIndex:idx++];
    
    [encoder setFragmentBuffer:barBuffer offset:0 atIndex:0];
    [encoder setFragmentBuffer:projBuffer offset:0 atIndex:1];
    
    const NSUInteger offset = [self vertexOffsetWithOffset:[_series info].offset];
    const NSUInteger count = [self vertexCountWithCount:[_series info].count];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:offset vertexCount:count];
    
    [encoder popDebugGroup];
}

- (id<MTLRenderPipelineState>)renderPipelineStateWithProjection:(UniformProjection *)projection
{
    return [_engine pipelineStateWithProjection:projection vertFunc:[self vertexFunctionName] fragFunc:@"GeneralBar_Fragment"];
}

- (NSUInteger)vertexCountWithCount:(NSUInteger)count { return 4 * count; }

- (NSUInteger)vertexOffsetWithOffset:(NSUInteger)offset { return 4 * offset; }

- (NSString *)vertexFunctionName { return @""; }

- (id<MTLBuffer>)indexBuffer { return nil; }

@end


@implementation OrderedBar

- (instancetype)initWithEngine:(Engine *)engine series:(OrderedSeries *)series
{
    self = [super initWithEngine:engine series:series];
    if(self) {
        _orderedSeries = series;
    }
    return self;
}

- (NSString *)vertexFunctionName { return @"GeneralBar_VertexOrdered"; }

@end






