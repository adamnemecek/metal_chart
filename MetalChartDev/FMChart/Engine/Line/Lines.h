//
//  PolyLines.h
//  MetalChartDev
//
//  Created by Mori Keisuke on 2015/08/06.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import "Protocols.h"

@class Engine;
@class UniformProjection;
@class UniformLineAttributes;
@class UniformAxisConfiguration;
@class UniformAxisAttributes;
@class UniformPointAttributes;
@class OrderedSeries;
@class IndexedSeries;

@protocol Series;

@interface LinePrimitive : NSObject<Primitive>

@property (strong  , nonatomic) UniformLineAttributes * _Nonnull attributes;
@property (strong  , nonatomic) UniformPointAttributes * _Nullable pointAttributes;
@property (readonly, nonatomic) Engine * _Nonnull engine;

- (id<Series> _Nullable)series;

@end




@interface OrderedSeparatedLinePrimitive : LinePrimitive

@property (strong, nonatomic) OrderedSeries * _Nullable series;

- (instancetype _Nonnull)initWithEngine:(Engine * _Nonnull)engine
								   orderedSeries:(OrderedSeries * _Nullable)series
									  attributes:(UniformLineAttributes * _Nullable)attributes
;

@end


@interface PolyLinePrimitive : LinePrimitive
@end

@interface OrderedPolyLinePrimitive : PolyLinePrimitive

@property (strong, nonatomic) OrderedSeries * _Nullable series;

- (instancetype _Nonnull)initWithEngine:(Engine * _Nonnull)engine
								   orderedSeries:(OrderedSeries * _Nullable)series
									  attributes:(UniformLineAttributes * _Nullable)attributes
;

- (void)appendSampleData:(NSUInteger)count
		  maxVertexCount:(NSUInteger)maxCount
                    mean:(CGFloat)mean
                variance:(CGFloat)variant
			  onGenerate:(void (^_Nullable)(float x, float y))block
;

@end


@interface IndexedPolyLinePrimitive : PolyLinePrimitive

@property (strong, nonatomic) IndexedSeries * _Nullable series;

- (instancetype _Nonnull)initWithEngine:(Engine * _Nonnull)engine
								   indexedSeries:(IndexedSeries * _Nullable)series
									  attributes:(UniformLineAttributes * _Nullable)attributes
;

@end


@interface Axis : NSObject

@property (readonly, nonatomic) UniformAxisConfiguration * _Nonnull configuration;
@property (readonly, nonatomic) UniformAxisAttributes * _Nonnull axisAttributes;
@property (readonly, nonatomic) UniformAxisAttributes * _Nonnull majorTickAttributes;
@property (readonly, nonatomic) UniformAxisAttributes * _Nonnull minorTickAttributes;

@property (readonly, nonatomic) Engine * _Nonnull engine;

- (instancetype _Nonnull)initWithEngine:(Engine * _Nonnull)engine
;

- (void)encodeWith:(id<MTLRenderCommandEncoder> _Nonnull)encoder
        projection:(UniformProjection * _Nonnull)projection
     maxMajorTicks:(NSUInteger)maxCount
;

@end
