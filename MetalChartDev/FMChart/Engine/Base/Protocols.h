//
//  Protocols.h
//  FMChart
//
//  Created by Keisuke Mori on 2015/08/28.
//  Copyright © 2015年 freaks. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MTLRenderCommandEncoder;

@class FMUniformProjectionCartesian2D;

@protocol FMPrimitive <NSObject>

- (void)encodeWith:(id<MTLRenderCommandEncoder> _Nonnull)encoder
		projection:(FMUniformProjectionCartesian2D * _Nonnull)projection
;

@end

