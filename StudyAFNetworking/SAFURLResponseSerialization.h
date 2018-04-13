//
//  SAFURLResponseSerialization.h
//  StudyAFNetworking
//
//  Created by eason on 2018/4/13.
//  Copyright © 2018年 xineason. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SAFURLResponseSerialization <NSObject,NSSecureCoding,NSCopying>

-(nullable id)responseObjectForResponse:(nullable NSURLResponse *)response
                                   data:(nullable NSData *)data
                                  error:(NSError * _Nullable __autoreleasing *)error NS_SWIFT_NOTHROW;

@end

#pragma mark - response 解析器
@interface SAFHTTPResponseSerializer : NSObject <SAFURLResponseSerialization>

- (instancetype)init;

@property (nonatomic, assign) NSStringEncoding stringEncoding DEPRECATED_MSG_ATTRIBUTE("The string encoding is never used. AFHTTPResponseSerializer only validates status codes and content types but does not try to decode the received data in any way.");

+(instancetype)serializer;


/**
 接受的response status code 200 404 500
 see http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
 */
@property (nonatomic,copy,nullable) NSIndexSet *acceptableStatusCodes;


/**
 ContentType MINE
 */
@property (nonatomic,copy,nullable) NSSet<NSString *> *acceptableContentTypes;

/**
 判断返回对象是否正确

 @param response http返回对象
 @param data 数据
 @param error 错误
 @return YES NO
 */
- (BOOL)validateResponse:(nullable NSHTTPURLResponse *)response
                    data:(nullable NSData *)data
                   error:(NSError * _Nullable __autoreleasing *)error;


@end

NS_ASSUME_NONNULL_END

