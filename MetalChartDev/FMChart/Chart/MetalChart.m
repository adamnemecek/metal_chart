//
//  MetalChart.m
//  MetalChartDev
//
//  Created by Mori Keisuke on 2015/08/09.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import "MetalChart.h"
#import "NSArray+Utility.h"
#import "DeviceResource.h"

MTLPixelFormat determineDepthPixelFormat()
{
    return ([UIDevice currentDevice].systemVersion.floatValue >= 9) ?
    MTLPixelFormatDepth32Float_Stencil8 :
    MTLPixelFormatDepth32Float;
}

@interface MetalChart()

@property (strong, nonatomic) NSArray<id<FMRenderable>> *series;
@property (strong, nonatomic) NSSet<id<FMProjection>> *projectionSet;

@property (strong, nonatomic) NSArray<id<FMAttachment>> *preRenderables;
@property (strong, nonatomic) NSArray<id<FMAttachment>> *postRenderables;

@property (strong, nonatomic) dispatch_semaphore_t semaphore;

@end

@implementation MetalChart

- (instancetype)init
{
	self = [super init];
	if(self) {
		_series = [NSArray array];
		_projectionSet = [NSSet set];
		_preRenderables = [NSArray array];
		_postRenderables = [NSArray array];
		_semaphore = dispatch_semaphore_create(1);
        _clearDepth = 0;
	}
	return self;
}

- (void)mtkView:(MetalView *)view drawableSizeWillChange:(CGSize)size
{
	// 描画前にバッファへ書き込むのでここは無視する.
}

// かなり長く見えるが、同期を短くしたり分岐を整理するためだけの行が多い. 大雑把に言って、
// ・semaphore_wait 前は 各配列を破綻しないようキャプチャ / projectionの更新
// ・semaphore_wait 内では preRenderable / series / postRenderable を描画
// ・semaphore_signale 後は レンダリング結果をキューに入れてコミット
// という流れになる. 実際サブルーチン化してリファクタリングするのは容易である.
- (void)drawInMTKView:(MetalView *)view
{
    const CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    const long timeout = dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_NOW);
    if(timeout != 0) {
        NSLog(@"timeout occurred.");
        return;
    }
    
    view.clearDepth = self.clearDepth;
    
	void (^willDraw)(MetalChart * _Nonnull) = _willDraw;
	if(willDraw != nil) willDraw(self);
	
	NSArray<id<FMRenderable>> *seriesArray = nil;
	NSArray<id<FMAttachment>> *preRenderables = nil;
	NSArray<id<FMAttachment>> *postRenderables = nil;
	NSSet<id<FMProjection>> *projections = nil;
    id<FMCommandBufferHook> hook = nil;
	
	@synchronized(self) {
		seriesArray = _series;
		preRenderables = _preRenderables;
		postRenderables = _postRenderables;
		projections = _projectionSet;
        hook = _bufferHook;
	}
	
	for(id<FMProjection> projection in projections) {
		[projection configure:view padding:_padding];
		[projection writeToBuffer];
	}
	
	id<MTLCommandBuffer> buffer = nil;
	id<MTLDrawable> drawable = nil;
	
	MTLRenderPassDescriptor *pass = view.currentRenderPassDescriptor;
	if(pass) {
		drawable = view.currentDrawable;
		if(drawable) {
			buffer = [[FMDeviceResource defaultResource].queue commandBuffer];
            
            [hook chart:self willStartEncodingToBuffer:buffer];
            
			id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:pass];
			
			for(id<FMAttachment> renderable in preRenderables) {
				[renderable encodeWith:encoder chart:self view:view];
			}
			
            const RectPadding pad = _padding;
            const CGSize size = view.drawableSize;
            const CGFloat scale = [UIScreen mainScreen].scale;
            const NSUInteger w  = size.width, h = size.height;
            const NSUInteger l = pad.left * scale, r = pad.right * scale;
            const NSUInteger t = pad.top * scale, b = pad.bottom * scale;
            
            const MTLScissorRect padRect = {l, t, w-(l+r), h-(t+b)};
            [encoder setScissorRect:padRect];
            
			const NSUInteger count = seriesArray.count;
			for(NSUInteger i = 0; i < count; ++i) {
				id<FMRenderable> series = seriesArray[i];
				[series encodeWith:encoder chart:self];
			}
            const MTLScissorRect orgRect = {0, 0, w, h};
            [encoder setScissorRect:orgRect];
			
			for(id<FMAttachment> renderable in postRenderables) {
				[renderable encodeWith:encoder chart:self view:view];
			}
			
			[encoder endEncoding];
            
            [hook chart:self willCommitBuffer:buffer];
		}
	}
	
    void (^didDraw)(MetalChart * _Nonnull) = _didDraw;
    if(didDraw != nil) didDraw(self);
    
	if(drawable) {
		__block dispatch_semaphore_t semaphore = _semaphore;
		[buffer presentDrawable:drawable];
		[buffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
			dispatch_semaphore_signal(semaphore);
		}];
		[buffer commit];
	} else {
		dispatch_semaphore_signal(_semaphore);
        NSLog(@"drawable was not available.");
	}
    const CFAbsoluteTime interval = (CFAbsoluteTimeGetCurrent() - startTime) * 1000;
    if(interval > 4) {
        NSLog(@"frame time was %.1f", interval);
    }
}

- (void)addSeries:(id<FMRenderable>)series
{
	@synchronized(self) {
		if(![_series containsObject:series]) {
			_series = [_series arrayByAddingObject:series];
            if([series conformsToProtocol:@protocol(FMDepthClient)]) {
                [self reconstructDepthClients];
            }
		}
	}
}

- (void)addSeriesArray:(NSArray<id<FMRenderable>> *)series
{
	const NSInteger count = series.count;
	@synchronized(self) {
		for(NSInteger i = 0; i < count; ++i) {
			[self addSeries:series[i]];
		}
	}
}

// immutableなcollectionを使ってるので非常にまどろっこしいが、描画サイクルの度に
// 防御的コピーを強制されるならこちらの方がよほどパフォーマンス的にはまともだと思われる
- (void)removeSeries:(id<FMRenderable>)series
{
	@synchronized(self) {
		const NSUInteger idx = [_series indexOfObject:series];
		if(idx != NSNotFound) {
			_series = [_series arrayByRemovingObjectAtIndex:idx];
            if([series conformsToProtocol:@protocol(FMDepthClient)]) {
                [self reconstructDepthClients];
            }
		}
	}
}

- (void)addProjection:(id<FMProjection>)projection {
	@synchronized(self) {
		_projectionSet = [_projectionSet setByAddingObject:projection];
	}
}

- (void)addProjections:(NSArray<id<FMProjection>> *)projections {
	@synchronized(self) {
		_projectionSet = [_projectionSet setByAddingObjectsFromArray:projections];
	}
}

- (void)removeProjection:(id<FMProjection>)projection {
	@synchronized(self) {
		if([_projectionSet containsObject:projection]) {
			NSMutableSet *set = [_projectionSet mutableCopy];
			[set removeObject:projection];
			_projectionSet = [set copy];
		}
	}
}

- (void)addPreRenderable:(id<FMAttachment>)object
{
	@synchronized(self) {
        NSArray <id<FMAttachment>> *old = _preRenderables;
		_preRenderables = [_preRenderables arrayByAddingObjectIfNotExists:object];
        if(old != _preRenderables && [object conformsToProtocol:@protocol(FMDepthClient)]) {
            [self reconstructDepthClients];
        }
	}
}

- (void)insertPreRenderable:(id<FMAttachment>)object atIndex:(NSUInteger)index
{
	@synchronized(self) {
		NSArray <id<FMAttachment>> *old = _preRenderables;
		_preRenderables = [_preRenderables arrayByInsertingObjectIfNotExists:object atIndex:index];
		if(old != _preRenderables && [object conformsToProtocol:@protocol(FMDepthClient)]) {
			[self reconstructDepthClients];
		}
	}
}

- (void)addPreRenderables:(NSArray<id<FMAttachment>> *)array
{
	@synchronized(self) {
		for(id<FMAttachment> pre in array) [self addPreRenderable:pre];
	}
}

- (void)removePreRenderable:(id<FMAttachment>)object
{
	@synchronized(self) {
        NSArray <id<FMAttachment>> *old = _preRenderables;
		_preRenderables = [_preRenderables arrayByRemovingObject:object];
        if(old != _preRenderables && [object conformsToProtocol:@protocol(FMDepthClient)]) {
            [self reconstructDepthClients];
        }
	}
}

- (void)addPostRenderable:(id<FMAttachment>)object
{
	@synchronized(self) {
        NSArray <id<FMAttachment>> *old = _postRenderables;
		_postRenderables = [_postRenderables arrayByAddingObjectIfNotExists:object];
        if(old != _postRenderables && [object conformsToProtocol:@protocol(FMDepthClient)]) {
            [self reconstructDepthClients];
        }
	}
}

- (void)addPostRenderables:(NSArray<id<FMAttachment>> *)array
{
	@synchronized(self) {
		for(id<FMAttachment> post in array) [self addPostRenderable:post];
	}
}

- (void)removePostRenderable:(id<FMAttachment>)object
{
	@synchronized(self) {
        NSArray <id<FMAttachment>> *old = _postRenderables;
		_postRenderables = [_postRenderables arrayByRemovingObject:object];
        if(old != _postRenderables && [object conformsToProtocol:@protocol(FMDepthClient)]) {
            [self reconstructDepthClients];
        }
	}
}

- (void)removeAll
{
    @synchronized(self) {
        _series = [NSArray array];
        _projectionSet = [NSSet set];
        _preRenderables = [NSArray array];
        _postRenderables = [NSArray array];
        [self reconstructDepthClients];
    }
}

- (void)setClearDepth:(CGFloat)clearDepth
{
    if(_clearDepth != clearDepth) {
        @synchronized(self) {
            _clearDepth = clearDepth;
            [self reconstructDepthClients];
        }
    }
}

// このメソッドはprivateメソッドなので、synchronizedブロックを使っていない. 呼び出す側で管理する事.
- (void)reconstructDepthClients
{
    NSMutableArray<id> *objects = [NSMutableArray array];
    [objects addObjectsFromArray:_preRenderables];
    [objects addObjectsFromArray:_series];
    [objects addObjectsFromArray:_postRenderables];
    
    CGFloat currentBase = 0;
    CGFloat clearVal = 0;
    for(id obj in objects) {
        if([obj conformsToProtocol:@protocol(FMDepthClient)]) {
            CGFloat v = [(id<FMDepthClient>)obj requestDepthRangeFrom:currentBase objects:objects];
            currentBase += fabs(v);
            clearVal += fabs(MIN(0, v));
        }
    }
    _clearDepth = clearVal;
}

@end








