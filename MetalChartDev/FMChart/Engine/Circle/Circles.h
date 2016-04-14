//
//  Circles.h
//  FMChart
//
//  Created by Keisuke Mori on 2015/11/18.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Protocols.h"

@class FMEngine;
@class FMUniformArcConfiguration;
@class FMUniformArcAttributesArray;
@class FMUniformProjectionPolar;
@class FMIndexedFloatBuffer;

@interface FMArcPrimitive : NSObject

@property (nonatomic, readonly) FMEngine * _Nonnull engine;
@property (nonatomic, readonly) FMUniformArcConfiguration * _Nonnull configuration;
@property (nonatomic, readonly) FMUniformArcAttributesArray * _Nonnull attributes;

- (instancetype _Nonnull)initWithEngine:(FMEngine * _Nonnull)engine
						  configuration:(FMUniformArcConfiguration * _Nullable)conf
							 attributes:(FMUniformArcAttributesArray * _Nullable)attr
					 attributesCapacity:(NSUInteger)capacity
NS_DESIGNATED_INITIALIZER;

- (instancetype _Nonnull)init
UNAVAILABLE_ATTRIBUTE;

- (void)encodeWith:(id<MTLRenderCommandEncoder> _Nonnull)encoder
		projection:(FMUniformProjectionPolar * _Nonnull)projection
			values:(FMIndexedFloatBuffer * _Nonnull)values
			offset:(NSUInteger)offset
			 count:(NSUInteger)count
;

@end


@interface FMContinuosArcPrimitive : FMArcPrimitive

@end
