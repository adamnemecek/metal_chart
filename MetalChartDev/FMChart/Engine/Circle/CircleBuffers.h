//
//  CircleBuffers.h
//  MetalChartDev
//
//  Created by Keisuke Mori on 2015/11/18.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import "circle_shared.h"

@protocol MTLBuffer;

@class FMDeviceResource;

@interface FMUniformArcConfiguration : NSObject

@property (nonatomic, readonly) id<MTLBuffer> _Nonnull buffer;
@property (nonatomic, readonly) uniform_arc_configuration * _Nonnull conf;

- (instancetype _Nonnull)initWithResource:(FMDeviceResource * _Nonnull)resource
NS_DESIGNATED_INITIALIZER;

- (instancetype _Nonnull)init
UNAVAILABLE_ATTRIBUTE;

- (void)setInnerRadius:(CGFloat)radius;
- (void)setOuterRadius:(CGFloat)radius;
- (void)setRadianOffset:(CGFloat)radian;

@end




@interface FMUniformArcAttributes : NSObject

@property (nonatomic, readonly) uniform_arc_attributes * _Nonnull attr;

- (instancetype _Nonnull)init
UNAVAILABLE_ATTRIBUTE;

- (void)setInnerRadius:(CGFloat)radius;
- (void)setOuterRadius:(CGFloat)radius;
- (void)setColorRed:(float)r green:(float)g blue:(float)b alpha:(float)a;
- (void)setColor:(const vector_float4 *_Nonnull)color;

@end




@interface FMUniformArcAttributesArray : NSObject

@property (nonatomic, readonly) id<MTLBuffer> _Nonnull buffer;
@property (nonatomic, readonly) NSArray<FMUniformArcAttributes*> * _Nonnull array;

- (instancetype _Nonnull)initWithResource:(FMDeviceResource * _Nonnull)resource
								 capacity:(NSUInteger)capacity
;

- (instancetype _Nonnull)init
UNAVAILABLE_ATTRIBUTE;

// indexチェックは行わない、注意する事.
- (FMUniformArcAttributes * _Nonnull)objectAtIndexedSubscript:(NSUInteger)index;

@end

