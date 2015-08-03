//
//  DeviceResource.m
//  mmd_dev
//
//  Created by Keisuke Mori on 2014/08/22.
//  Copyright (c) 2014年 wfreaks. All rights reserved.
//

#import "DeviceResource.h"

@implementation DeviceResource
{
	NSMutableDictionary *_renderStates;
	NSMutableDictionary *_computeStates;
	NSMutableDictionary *_samplerStates;
}

- (id)init
{
	self = [super init];
	if( self ) {
		_device = MTLCreateSystemDefaultDevice();
		_library = [_device newDefaultLibrary];
		_renderStates = [NSMutableDictionary dictionary];
		_computeStates = [NSMutableDictionary dictionary];
		_samplerStates = [NSMutableDictionary dictionary];
		_queue = [_device newCommandQueue];
	}
	return self;
}

- (BOOL)addRenderPipelineState:(id<MTLRenderPipelineState>)state
{
	NSString *label = state.label;
	if( label.length > 0 && _renderStates[label] == nil ) {
		_renderStates[label] = state;
		return YES;
	}
	return NO;
}

- (BOOL)addComputePipelineState:(id<MTLComputePipelineState>)state
						 forKey:(NSString *)key
{
	if( key.length > 0 && _computeStates[key] == nil ) {
		_computeStates[key] = state;
		return YES;
	}
	return NO;
}

- (BOOL)addSamplerState:(id<MTLSamplerState>)state
				 forKey:(NSString *)key
{
	if( key.length > 0 && _samplerStates[key] == nil ) {
		_samplerStates[key] = state;
		return YES;
	}
	return NO;
}

+ (DeviceResource *)defaultResource
{
	static DeviceResource* res = nil;
	if( res == nil ) {
		res = [[DeviceResource alloc] init];
	}
	return res;
}

@end
