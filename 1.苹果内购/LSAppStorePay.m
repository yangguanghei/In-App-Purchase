//
//  LSAppStorePay.m
//  1.苹果内购
//
//  Created by 梁森 on 2020/7/10.
//  Copyright © 2020 梁森. All rights reserved.
//

#import "LSAppStorePay.h"

#import <StoreKit/StoreKit.h>

@interface LSAppStorePay ()<SKPaymentTransactionObserver,SKProductsRequestDelegate>

@property (nonatomic, copy) NSString * goodsId;

@end

@implementation LSAppStorePay


- (instancetype)init{
    self = [super init];
    if (self) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];// 4.设置支付服务
    }
    return self;
}

- (void)buyWithGoodsId:(NSString *)goodsId{
    if ([SKPaymentQueue canMakePayments]) {
        [self requestAppleProduct:goodsId];
    }else{
        NSLog(@"没有内购权限");
    }
}
/// 请求苹果后台商品
- (void)requestAppleProduct:(NSString *)goodsId{
    self.goodsId = goodsId;
    // 这里的com.czchat.CZChat01就对应着苹果后台的商品ID,他们是通过这个ID进行联系的。
    NSArray *product = [[NSArray alloc] initWithObjects:goodsId,nil];
    NSSet *nsset = [NSSet setWithArray:product];
    //SKProductsRequest参考链接：https://developer.apple.com/documentation/storekit/skproductsrequest
    //SKProductsRequest 一个对象，可以从App Store检索有关指定产品列表的本地化信息。
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:nsset];// 初始化请求
    request.delegate = self;
    [request start];// 开始请求
}
#pragma mark ------ SKProductsRequestDelegate
// 返回的商品
- (void) productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    NSArray *product = response.products;
    if([product count] == 0){
        NSLog(@"没有产品");
        return;
    }
    SKProduct *requestProduct = nil;
    for (SKProduct *pro in product) {
//        NSLog(@"%@", [pro description]);
//        NSLog(@"%@", [pro localizedTitle]);
//        NSLog(@"%@", [pro localizedDescription]);
//        NSLog(@"%@", [pro price]);
//        NSLog(@"%@", [pro productIdentifier]);
        // 如果后台消费条目的ID与我这里需要请求的一样（用于确保订单的正确性）
        if([pro.productIdentifier isEqualToString:self.goodsId]){
            requestProduct = pro;
        }
    }
    // 发送购买请求，创建票据  这个时候就会有弹框了
    SKPayment *payment = [SKPayment paymentWithProduct:requestProduct];
    [[SKPaymentQueue defaultQueue] addPayment:payment];//将票据加入到交易队列
    
}
#pragma mark ------ SKRequestDelegate (@protocol SKProductsRequestDelegate <SKRequestDelegate>)
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    NSLog(@"请求失败%@", error);
}
- (void)requestDidFinish:(SKRequest *)request{
    NSLog(@"反馈请求的产品信息结束：%@", request);
}
#pragma mark ------ SKPaymentTransactionObserver 监听购买结果
// 监听购买结果
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transaction{
    if (self.delegate && [self.delegate respondsToSelector:@selector(LSAppStorePay:responseAppStoreStatus:error:)]) {
        [self.delegate LSAppStorePay:self responseAppStoreStatus:@{@"value":transaction} error:nil];
    }
    
    if (transaction.count > 0) {
        //检测是否有未完成的交易
        SKPaymentTransaction* tran = [transaction firstObject];
        if (tran.transactionState == SKPaymentTransactionStatePurchased) {
            [self completeTransaction:tran];
            [[SKPaymentQueue defaultQueue] finishTransaction:tran];//未完成的交易在此给它结束
            return;
        }
    }
    for(SKPaymentTransaction *tran in transaction){
        switch (tran.transactionState) {
            case SKPaymentTransactionStatePurchased:{
                NSLog(@"交易完成");
                // 购买后告诉交易队列，把这个成功的交易移除掉。
                //走到这就说明这单交易走完了，无论成功失败，所以要给它移出。finishTransaction
                [self completeTransaction:tran];//这儿出了问题抛异常，导致下面一句代码没执行
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
            }
                break;
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"商品添加进列表");
                break;
            case SKPaymentTransactionStateRestored:
                NSLog(@"已经购买过商品");
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                break;
            case SKPaymentTransactionStateFailed:
                NSLog(@"交易失败");
                [[SKPaymentQueue defaultQueue] finishTransaction:tran];
                break;
            case SKPaymentTransactionStateDeferred:
                NSLog(@"交易还在队列里面，但最终状态还没有决定");
                break;
            default:
                break;
        }
    }
}
#pragma mark ------ 支付完成
- (void)completeTransaction:(SKPaymentTransaction *)transaction{
    //交易验证 本地验证方法
    /*NSURL *recepitURL = [[NSBundle mainBundle] appStoreReceiptURL];
     NSData *receipt = [NSData dataWithContentsOfURL:recepitURL];
     if(!receipt){
     
     }
     NSError *error;
     NSDictionary *requestContents = @{
     @"receipt-data": [receipt base64EncodedStringWithOptions:0]
     };
     NSLog(@"requestContentstr:%@",[receipt base64EncodedStringWithOptions:0]);
     NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents
     options:0
     error:&error];
     //In the test environment, use https://sandbox.itunes.apple.com/verifyReceipt
     //In the real environment, use https://buy.itunes.apple.com/verifyReceipt
     // Create a POST request with the receipt data.
     NSURL *storeURL = [NSURL URLWithString:@"https://sandbox.itunes.apple.com/verifyReceipt"];
     NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
     [storeRequest setHTTPMethod:@"POST"];
     [storeRequest setHTTPBody:requestData];
     
     // Make a connection to the iTunes Store on a background queue.
     NSOperationQueue *queue = [[NSOperationQueue alloc] init];
     [NSURLConnection sendAsynchronousRequest:storeRequest queue:queue
     completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
     if (connectionError) {
     } else {
     NSError *error;
     NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
     if (!jsonResponse) {  }
     //Parse the Response
     NSLog(@"成功了：%@",jsonResponse);
     }
     }];*/
    
    //此时告诉后台交易成功，并把receipt传给后台验证
   __block NSString *transactionReceiptString= nil;
    //系统IOS7.0以上获取支付验证凭证的方式应该改变，切验证返回的数据结构也不一样了。
    // 验证凭据，获取到苹果返回的交易凭据
    // appStoreReceiptURL iOS7.0增加的，购买交易完成后，会将凭据存放在该地址
    NSURLRequest *appstoreRequest = [NSURLRequest requestWithURL:[[NSBundle mainBundle] appStoreReceiptURL]];
    // 从沙盒中获取到购买凭据
//    NSData * receiptData = [NSURLConnection sendSynchronousRequest:appstoreRequest returningResponse:nil error:&error];
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:appstoreRequest completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            return;
        }
        NSData * receiptData = data;
        // 20 BASE64 常用的编码方案，通常用于数据传输，以及加密算法的基础算法，传输过程中能够保证数据传输的稳定性 21 BASE64是可以编码和解码的 22
        transactionReceiptString = [receiptData base64EncodedStringWithOptions:0];
        if (self.delegate && [self.delegate respondsToSelector:@selector(LSAppStorePay:responseAppStoreSuccess:error:)]) {
            [self.delegate LSAppStorePay:self responseAppStoreSuccess:@{@"value":transactionReceiptString} error:error];
        }
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    }] resume];
    
}

//结束后一定要销毁
- (void)dealloc{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

@end
