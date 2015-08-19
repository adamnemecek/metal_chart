//
//  MCAxis.m
//  MetalChartDev
//
//  Created by Mori Keisuke on 2015/08/11.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import "MCAxis.h"
#import "Lines.h"
#import "Series.h"


@interface MCAxis()

@property (readonly, nonatomic) MCDimensionalProjection *orthogonal;

@end



@interface MCBlockAxisConfigurator()

@property (copy, nonatomic) MCAxisConfiguratorBlock _Nonnull block;

@end




@implementation MCAxis

- (instancetype)initWithEngine:(LineEngine *)engine
					Projection:(MCSpatialProjection *)projection
					 dimension:(NSInteger)dimensionId
				 configuration:(id<MCAxisConfigurator>)conf
{
	self = [super init];
	if(self) {
		_projection = projection;
        _axis = [[Axis alloc] initWithEngine:engine];
		_conf = conf;
		_dimension = [projection dimensionWithId:dimensionId];
		
		if(_dimension == nil) {
			abort();
		}
        
		const NSUInteger dimIndex = [projection.dimensions indexOfObject:_dimension];
        [_axis.uniform setDimensionIndex:dimIndex];
		
		_orthogonal = projection.dimensions[(dimIndex == 0) ? 1 : 0];
		
		[self setupDefaultAttributes];
	}
	return self;
}

- (void)willEncodeWith:(id<MTLRenderCommandEncoder>)encoder
				 chart:(MetalChart *)chart
				  view:(MTKView *)view
{
	[_conf configureUniform:_axis.uniform withDimension:_dimension orthogonal:_orthogonal];
    [_axis encodeWith:encoder projection:_projection.projection];
}

- (void)setMinorTickCountPerMajor:(NSUInteger)count
{
    _axis.uniform.minorTicksPerMajor = (uint8_t)count;
}

- (void)setupDefaultAttributes
{
	UniformAxisAttributes *axis = _axis.uniform.axisAttributes;
	UniformAxisAttributes *major = _axis.uniform.majorTickAttributes;
	UniformAxisAttributes *minor = _axis.uniform.minorTickAttributes;
	
	[axis setColorWithRed:0 green:0 blue:0 alpha:0.5];
	[axis setWidth:3];
	[axis setLineLength:160];
	
	[major setColorWithRed:0 green:0 blue:0 alpha:0.3];
	[major setWidth:2];
	[major setLineLength:10];
	[major setLengthModifierStart:-1 end:0];
	
	[minor setColorWithRed:0 green:0 blue:0 alpha:0.3];
	[minor setWidth:1];
	[minor setLineLength:6];
	[minor setLengthModifierStart:0 end:1];
}

@end


@implementation MCBlockAxisConfigurator

- (instancetype)initWithBlock:(MCAxisConfiguratorBlock)block
{
	self = [super init];
	if(self) {
		self.block = block;
	}
	return self;
}

- (void)configureUniform:(UniformAxis *)uniform
		   withDimension:(MCDimensionalProjection *)dimension
			  orthogonal:(MCDimensionalProjection * _Nonnull)orthogonal
{
	_block(uniform, dimension, orthogonal);
}

@end

