//
//  LSAppStorePay.h
//  1.苹果内购
//
//  Created by 梁森 on 2020/7/10.
//  Copyright © 2020 梁森. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 购买类
@class LSAppStorePay;
// 购买代理
@protocol LSAppStorePayDelegate <NSObject>

@optional
// 成功回调
- (void)LSAppStorePay:(LSAppStorePay *)appStorePay responseAppStoreSuccess:(NSDictionary *)dict error:(NSError *)error;
// 支付结果回调
- (void)LSAppStorePay:(LSAppStorePay *)appStorePay responseAppStoreStatus:(NSDictionary *)dict error:(NSError *)error;
@end

@interface LSAppStorePay : NSObject

@property (nonatomic, weak) id<LSAppStorePayDelegate>delegate;

/// 购买商品
- (void)buyWithGoodsId:(NSString *)goodsId;

@end

NS_ASSUME_NONNULL_END
