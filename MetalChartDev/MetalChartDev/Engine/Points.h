//
//  Points.h
//  MetalChartDev
//
//  Created by Keisuke Mori on 2015/08/27.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Protocols.h"

@class Engine;
@class UniformProjection;
@class UniformPlotRectAttributes;
@class UniformPointAttributes;
@class OrderedSeries;
@class IndexedSeries;

@protocol MTLRenderCommandEncoder;
@protocol Series;

@interface PointPrimitive : NSObject<Primitive>

@property (readonly, nonatomic) Engine * _Nonnull engine;
@property (readonly, nonatomic) UniformPointAttributes * _Nonnull attributes;

- (id<Series> _Nullable)series;

@end

@interface OrderedPointPrimitive : PointPrimitive

@property (strong, nonatomic) OrderedSeries * _Nullable series;

- (instancetype _Nonnull)initWithEngine:(Engine * _Nonnull)engine
                                          series:(OrderedSeries * _Nullable)series
									  attributes:(UniformPointAttributes * _Nullable)attributes
;
@end

@interface IndexedPointPrimitive : PointPrimitive

@property (strong, nonatomic) IndexedSeries * _Nullable series;

- (instancetype _Nonnull)initWithEngine:(Engine * _Nonnull)engine
										  series:(IndexedSeries * _Nullable)series
									  attributes:(UniformPointAttributes * _Nullable)attributes
;
@end


@interface DynamicPointPrimitive : PointPrimitive

@property (strong, nonatomic) id<Series> _Nullable series;

- (instancetype _Nonnull)initWithEngine:(Engine * _Nonnull)engine
										  series:(id<Series> _Nullable)series
									  attributes:(UniformPointAttributes * _Nullable)attributes
;
@end

