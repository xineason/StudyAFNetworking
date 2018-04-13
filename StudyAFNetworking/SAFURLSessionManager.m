//
//  SAFURLSessionManager.m
//  StudyAFNetworking
//
//  Created by eason on 2018/4/13.
//  Copyright © 2018年 xineason. All rights reserved.
//

#import "SAFURLSessionManager.h"
#import <objc/runtime.h>

//如果没有定义Foundation版本，则定义一个版本号和Foundation-1140.11(iOS_8)
#ifndef NSFoundationVersionNumber_iOS_8_0
#define NSFoundationVersionNumber_With_Fixed_5871104061079552_bug 1140.11
#else
#define NSFoundationVersionNumber_With_Fixed_5871104061079552_bug NSFoundationVersionNumber_iOS_8_0
#endif

//一系列的GCD的定义，主要用户task处理


/**
 使用单例创建一个同步GCD queue
 @return 一个同步队列
 */
static dispatch_queue_t url_session_manager_creation_queue(){
    static dispatch_queue_t saf_url_session_manager_creation_queue;
    static dispatch_once_t onceToken;
    //单例模式，只运行一次
    dispatch_once(&onceToken, ^{
        //DISPATCH_QUEUE_CONCURRENT 异步
        //DISPATCH_QUEUE_SERIAL 同步
        saf_url_session_manager_creation_queue = dispatch_queue_create("com.alamofire.networking.session.manager.creation", DISPATCH_QUEUE_SERIAL);
    });
    return saf_url_session_manager_creation_queue;
};

/**
 foundation版本小于8 使用串行队列来同步创建会话
 @param block 安全线程中调用的block
 */
static void url_session_manager_create_task_safely(dispatch_block_t block){
    if (NSFoundationVersionNumber < NSFoundationVersionNumber_With_Fixed_5871104061079552_bug) {
        // Fix of bug
        // Open Radar:http://openradar.appspot.com/radar?id=5871104061079552 (status: Fixed in iOS8)
        // Issue about:https://github.com/AFNetworking/AFNetworking/issues/2093
        dispatch_sync(url_session_manager_creation_queue(), block);
    }else{
        block();
    }
}

/**
 创建一个并发队列，用于处理从网络获取数据
 @return 一个并发队列
 */
static dispatch_queue_t url_session_manager_processing_queue(){
    static dispatch_queue_t saf_url_session_manager_processing_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        saf_url_session_manager_processing_queue = dispatch_queue_create("com.alamofire.networking.session.manager.processing", DISPATCH_QUEUE_CONCURRENT);
    });
    return saf_url_session_manager_processing_queue;
}

/**
 创建网络获取事件之后的执行群组
 @return CGD群组
 */
static dispatch_group_t url_session_manager_completion_group(){
    static dispatch_group_t saf_url_session_manager_completion_group;
    static dispatch_once_t onceToke;
    dispatch_once(&onceToke, ^{
        saf_url_session_manager_completion_group = dispatch_group_create();
    });
    return saf_url_session_manager_completion_group;
}

/**************定义通知************/
//执行通知
NSString * const SAFNetworkingTaskDidResumeNotification = @"com.alamofire.networking.task.resume";
//执行完成通知
NSString * const SAFNetworkingTaskDidCompleteNotification = @"com.alamofire.networking.task.complete";
//挂起通知
NSString * const SAFNetworkingTaskDidSuspendNotification = @"com.alamofire.networking.task.suspend";
//任务结束通知
NSString * const SAFURLSessionDidInvalidateNotification = @"com.alamofire.networking.session.invalidate";
//下载文件失败通知 ？？？
NSString * const SAFURLSessionDownloadTaskDidFailToMoveFileNotification = @"com.alamofire.networking.session.download.file-manager-error";

NSString * const SAFNetworkingTaskDidCompleteSerializedResponseKey = @"com.alamofire.networking.task.complete.serializedresponse";
NSString * const SAFNetworkingTaskDidCompleteResponseSerializerKey = @"com.alamofire.networking.task.complete.responseserializer";
NSString * const SAFNetworkingTaskDidCompleteResponseDataKey = @"com.alamofire.networking.complete.finish.responsedata";
NSString * const SAFNetworkingTaskDidCompleteErrorKey = @"com.alamofire.networking.task.complete.error";
NSString * const SAFNetworkingTaskDidCompleteAssetPathKey = @"com.alamofire.networking.task.complete.assetpath";

//定义lock name
static NSString * const AFURLSessionManagerLockName = @"com.alamofire.networking.session.manager.lock";
//定义最大的后台上传任务个数
static NSUInteger const AFMaximumNumberOfAttemptsToRecreateBackgroundSessionUploadTask = 3;


/**************定义block************/






@interface SAFURLSessionManager()
//session配置
@property (readwrite,nonatomic,strong) NSURLSessionConfiguration *sessionConfiguration;
//执行session的操作队列
@property (readwrite,nonatomic,strong) NSOperationQueue *operationQueue;
//会话，所有的请求task共用这一个会话
@property (readwrite,nonatomic,strong) NSURLSession *session;
//任务代理对象的字典，key为task指针地址，value为自定义的代理对象
@property (readwrite,nonatomic,strong) NSMutableDictionary *mutableTaskDelegatesKeyedByTaskIdentifier;
//操作自定义 mutableTaskDelegatesKeyedByTaskIdentifier delegate的增删改查，防止内存泄露
@property (readwrite,nonatomic,strong) NSLock *lock;

@end


@implementation SAFURLSessionManager

-(instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)configuration {
    self = [super init];
    if(!self){
        return nil;
    }
    
    if (!configuration) {
        //如果外部没有传入配置的花采用默认设置，默认配置项里面包括timeout等一些列的设置
        configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    }
    self.sessionConfiguration = configuration;
    
    self.operationQueue = [[NSOperationQueue alloc] init];
    //设置最大的异步执行线程为1个，这里为什么暂时没搞懂
    self.operationQueue.maxConcurrentOperationCount = 1;
    
    self.session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration delegate:self delegateQueue:self.operationQueue];
    
    //任务代理对象的字典
    self.mutableTaskDelegatesKeyedByTaskIdentifier = [[NSMutableDictionary alloc] init];
    
    
    return self;
}




#pragma -mark NSURLSessionDelegate
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error{
    
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler{
    
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session API_AVAILABLE(ios(7.0), watchos(2.0), tvos(9.0)) API_UNAVAILABLE(macos){
    
}










































@end
