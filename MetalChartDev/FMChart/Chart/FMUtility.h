//
//  FMUtility.h
//  MetalChartDev
//
//  Created by Mori Keisuke on 2015/09/20.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import <Foundation/Foundation.h>

// モジュラーな設計を心がけると、使いかたの幅が広がると同時に、クラス階層と関係性の理解を強制されるが、
// アプリケーションコードはある意味では迂遠なものになる（実際にはそれが正しい姿だが、往々にして典型的なコードを要求される）。
// そのあたりの不満を解消するためのルーチン集がここに集められる.
// また、クラス関係を理解するためのエントリポイントとしての意味もある.

#import "FMAxisLabel.h"

@class MetalChart;
@class FMDimensionalProjection;
@class FMSpatialProjection;
@class FMProjectionUpdater;
@class FMAxis;
@class FMAxisLabel;
@class FMPlotArea;
@class FMGestureInterpreter;
@class Engine;

@protocol FMInteraction;
@protocol FMAxisConfigurator;
@protocol FMInterpreterStateRestriction;

@interface FMUtility : NSObject

@end

typedef FMProjectionUpdater * _Nullable (^DimensionConfigureBlock)(NSInteger dimensionID);

// Chartに対しての設定を簡潔にするためのオブジェクト.
// ただし、効率性や柔軟性を重視するなら、このクラスを使わずに手で設定することをお勧めする.
// (初期設定時の負荷など描画に比べれば微々たるものなので、効率が問題になることはまずないとは思う)
// また大体のことはこのクラスを使ってできるようにするつもりだが、凝った事をやろうとしているなら、
// 迷わずより低いレベルのクラスを直接使う事をお勧めする(綺麗により細かいコントロールができる魔法のクラスなんて存在しないし、
// 文字数より細かい制御など原理的にできる訳がない)

@interface FMConfigurator : NSObject

@property (readonly, nonatomic) NSArray<FMDimensionalProjection*> * _Nonnull dimensions;
@property (readonly, nonatomic) NSArray<FMProjectionUpdater*> * _Nonnull updaters;
@property (readonly, nonatomic) NSArray<FMSpatialProjection*> * _Nonnull space;
@property (readonly, nonatomic) MetalChart * _Nonnull chart;
@property (readonly, nonatomic) MTKView * _Nullable view;
@property (readonly, nonatomic) Engine * _Nonnull engine;
@property (readonly, nonatomic) NSInteger preferredFps;

// fps <= 0 では setNeedsRedraw がセットされた時のみ描画するようにMTKViewを調整する.
- (instancetype _Nonnull)initWithChart:(MetalChart * _Nonnull)chart
								engine:(Engine * _Nullable)engine
								  view:(MTKView * _Nullable)view
						  preferredFps:(NSInteger)fps
NS_DESIGNATED_INITIALIZER;

- (instancetype _Nonnull)init UNAVAILABLE_ATTRIBUTE;

// もしもidに対応するFMDimensionalProjectionがなければ、作成してblockを呼び出す. 
// 逆にすでに作成済みの場合はそれを使い、blockは呼ばれない.
// blockの戻り値でNonnullを返した場合は登録され、connectSpace:メソッドで自動的に使用される.
- (FMSpatialProjection * _Nonnull)spaceWithDimensionIds:(NSArray<NSNumber*> * _Nonnull)ids
										 configureBlock:(DimensionConfigureBlock _Nullable)block
;

- (FMProjectionUpdater * _Nullable)updaterWithDimensionId:(NSInteger)dimensionId;

- (id<FMInteraction> _Nullable)connectSpace:(NSArray<FMSpatialProjection*>* _Nonnull)space
							  toInterpreter:(FMGestureInterpreter * _Nonnull)interpreter
;

- (FMAxis * _Nullable)addAxisToDimensionWithId:(NSInteger)dimensionId
								   belowSeries:(BOOL)below
								  configurator:(id<FMAxisConfigurator> _Nonnull)configurator
										 label:(FMAxisLabelDelegateBlock _Nullable)block
;

- (FMPlotArea * _Nonnull)addPlotAreaWithColor:(UIColor * _Nonnull)color;

- (FMGestureInterpreter * _Nonnull)addInterpreterToPanRecognizer:(UIPanGestureRecognizer *_Nullable)pan
												 pinchRecognizer:(UIPinchGestureRecognizer * _Nullable)pinch
												stateRestriction:(id<FMInterpreterStateRestriction> _Nonnull)restriction
;

@end