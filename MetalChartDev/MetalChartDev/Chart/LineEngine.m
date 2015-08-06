//
//  LineEngine.m
//  MetalChartDev
//
//  Created by Keisuke Mori on 2015/08/03.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import "LineEngine_common.h"
#import "PolyLines.h"
#import <UIKit/UIKit.h>

@interface LineEngine()

@property (strong, nonatomic) DeviceResource *resource;

@property (strong, nonatomic) id<MTLDepthStencilState> depthState_writeDepth;
@property (strong, nonatomic) id<MTLDepthStencilState> depthState_noDepth;

@end

@implementation LineEngine

- (id)initWithResource:(DeviceResource *)resource
{
	self = [super init];
	if(self) {
		self.resource = [DeviceResource defaultResource];
        self.depthState_writeDepth = [self.class depthStencilStateWithResource:resource writeDepth:YES];
        self.depthState_noDepth = [self.class depthStencilStateWithResource:resource writeDepth:NO];
	}
	return self;
}

+ (id<MTLRenderPipelineState>)pipelineStateWithResource:(DeviceResource *)resource
											sampleCount:(NSUInteger)count
											pixelFormat:(MTLPixelFormat)format
                                             writeDepth:(BOOL)writeDepth
                                                indexed:(BOOL)indexed
{
	NSString *label = [NSString stringWithFormat:@"PolyLineEngineIndexed_%lu", (unsigned long)count];
	id<MTLRenderPipelineState> state = resource.renderStates[label];
	if(state == nil) {
		MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
		desc.label = label;
        NSString *vertFuncName = (indexed) ? @"PolyLineEngineVertexIndexed" : @"PolyLineEngineVertexOrdered";
        NSString *fragFuncName = (writeDepth) ? @"LineEngineFragment_WriteDepth" : @"LineEngineFragment_NoDepth";
		desc.vertexFunction = [resource.library newFunctionWithName:vertFuncName];
        desc.fragmentFunction = [resource.library newFunctionWithName:fragFuncName];
		desc.sampleCount = count;
        MTLRenderPipelineColorAttachmentDescriptor *cd = desc.colorAttachments[0];
		cd.pixelFormat = format;
        cd.blendingEnabled = YES;
        cd.rgbBlendOperation = MTLBlendOperationAdd;
        cd.alphaBlendOperation = MTLBlendOperationAdd;
        cd.sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        cd.sourceAlphaBlendFactor = MTLBlendFactorOne;
        cd.destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        cd.destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        
        desc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
        desc.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
        
		NSError *err = nil;
		state = [resource.device newRenderPipelineStateWithDescriptor:desc error:&err];
        if(err) {
            NSLog(@"error : %@", err);
        }
		[resource addRenderPipelineState:state];
	}
	return state;
}

+ (id<MTLDepthStencilState>)depthStencilStateWithResource:(DeviceResource *)resource
                                               writeDepth:(BOOL)writeDepth
{
	MTLDepthStencilDescriptor *desc = [[MTLDepthStencilDescriptor alloc] init];
    desc.depthCompareFunction = (writeDepth) ? MTLCompareFunctionGreater : MTLCompareFunctionAlways;
	desc.depthWriteEnabled = writeDepth;
	
	return [resource.device newDepthStencilStateWithDescriptor:desc];
}

- (void)encodeTo:(id<MTLCommandBuffer>)command
            pass:(MTLRenderPassDescriptor *)pass
          vertex:(VertexBuffer *)vertex
           index:(IndexBuffer *)index
      projection:(UniformProjection *)projection
      attributes:(UniformLineAttributes *)attributes
      seriesInfo:(UniformSeriesInfo *)info
{
    const NSUInteger sampleCount = projection.sampleCount;
    const MTLPixelFormat colorFormat = projection.colorPixelFormat;
    const BOOL writeDepth = ! attributes.enableOverlay;
    const BOOL indexed = (index != nil);
    id<MTLRenderPipelineState> renderState = [self.class pipelineStateWithResource:_resource sampleCount:sampleCount pixelFormat:colorFormat writeDepth:writeDepth indexed:indexed];
    id<MTLDepthStencilState> depthState = (writeDepth ? _depthState_writeDepth : _depthState_noDepth);
    id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
    [encoder setLabel:@"DrawLineEncoder"];
    [encoder pushDebugGroup:@"DrawLine"];
    [encoder setRenderPipelineState:renderState];
    [encoder setDepthStencilState:depthState];
    
    NSUInteger idx = 0;
    [encoder setVertexBuffer:vertex.buffer offset:0 atIndex:idx++];
    if( indexed ) {
        [encoder setVertexBuffer:index.buffer offset:0 atIndex:idx++];
    }
    [encoder setVertexBuffer:projection.buffer offset:0 atIndex:idx++];
    [encoder setVertexBuffer:attributes.buffer offset:0 atIndex:idx++];
    [encoder setVertexBuffer:info.buffer offset:0 atIndex:idx++];
    
    [encoder setFragmentBuffer:projection.buffer offset:0 atIndex:0];
    [encoder setFragmentBuffer:attributes.buffer offset:0 atIndex:1];
    
    const NSUInteger count = 6 * MAX(0, ((NSInteger)info.count) - 1);
    if(count > 0) {
        const NSUInteger offset = 6 * (info.offset);
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:offset vertexCount:count instanceCount:1];
    }
    [encoder endEncoding];
}

@end



