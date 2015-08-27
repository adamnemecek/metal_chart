//
//  MCRenderables.h
//  MetalChartDev
//
//  Created by Mori Keisuke on 2015/08/11.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MetalChart.h"

@class LinePrimitive;
@class BarPrimitive;
@class PointPrimitive;

@interface MCLineSeries : NSObject<MCRenderable, MCDepthClient>

@property (readonly, nonatomic) LinePrimitive * _Nonnull line;

- (instancetype _Null_unspecified)initWithLine:(LinePrimitive * _Nonnull)line;

@end


@interface MCBarSeries : NSObject<MCRenderable>

@property (readonly, nonatomic) BarPrimitive * _Nonnull bar;

- (instancetype _Null_unspecified)initWithBar:(BarPrimitive * _Nonnull)bar;

@end


@interface MCPointSeries : NSObject<MCRenderable>

@property (readonly, nonatomic) PointPrimitive * _Nonnull point;

- (instancetype _Null_unspecified)initWithPoint:(PointPrimitive * _Nonnull)point;

@end


@class PlotRect;

@interface MCPlotArea : NSObject<MCAttachment>

@property (readonly, nonatomic) UniformProjection * _Nonnull projection;
@property (readonly, nonatomic) PlotRect * _Nonnull rect;

- (instancetype _Null_unspecified)initWithRect:(PlotRect * _Nonnull)rect;

@end
