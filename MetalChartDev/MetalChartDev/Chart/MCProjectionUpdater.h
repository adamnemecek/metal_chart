//
//  MCProjectionUpdater.h
//  MetalChartDev
//
//  Created by Mori Keisuke on 2015/08/10.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MetalChart.h"

@protocol MCRestriction;

@interface MCProjectionUpdater : NSObject

@property (readonly, nonatomic) NSArray<id<MCRestriction>> * _Nonnull restrictions;

@property (strong, nonatomic) MCDimensionalProjection * _Nullable target;

- (instancetype _Nonnull)initWithTarget:(MCDimensionalProjection * _Nullable)target
;

+ (instancetype _Nonnull)updaterWithDimensionId:(NSInteger)dimensionId;

- (const CGFloat * _Nullable)sourceMinValue;
- (const CGFloat * _Nullable)sourceMaxValue;

- (void)addSourceValue:(CGFloat)value update:(BOOL)update;
- (void)clearSourceValues:(BOOL)update;

- (void)addRestrictionToLast:(id<MCRestriction> _Nonnull)object;
- (void)addRestrictionToFirst:(id<MCRestriction> _Nonnull)object;
- (void)removeRestriction:(id<MCRestriction> _Nonnull)object;

- (void)updateTarget;

@end

