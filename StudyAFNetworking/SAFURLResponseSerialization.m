//
//  SAFURLResponseSerialization.m
//  StudyAFNetworking
//
//  Created by eason on 2018/4/13.
//  Copyright © 2018年 xineason. All rights reserved.
//

#import "SAFURLResponseSerialization.h"

//定义错误key
NSString * const SAFURLResponseSerializationErrorDomain = @"com.alamofire.error.serialization.response";
NSString * const SAFNetworkingOperationFailingURLResponseErrorKey = @"com.alamofire.serialization.response.error.response";
NSString * const SAFNetworkingOperationFailingURLResponseDataErrorKey = @"com.alamofire.serialization.response.error.data";

static NSError *SAFErorrWithUnderlyingError(NSError *error,NSError *underlyingError){
    if (!error) {
        return underlyingError;
    }
    
    if (!underlyingError || error.userInfo[NSUnderlyingErrorKey]) {
        return error;
    }
    NSMutableDictionary *mutableUserInfo = [error.userInfo mutableCopy];
    mutableUserInfo[NSUnderlyingErrorKey] = underlyingError;
    
    return [[NSError alloc] initWithDomain:error.domain code:error.code userInfo:mutableUserInfo];
}



#pragma -mark response解析器，返回NSData
@implementation SAFHTTPResponseSerializer

-(instancetype)init{
    self = [super init];
    if (!self) {
        return nil;
    }
    //默认接受statuscode 为200-300 http协议里面200-300为返回正确结果的范围
    self.acceptableStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
    self.acceptableContentTypes = nil;
    return self;
}

+(instancetype)serializer{
    return [[self alloc] init];
}

-(id)responseObjectForResponse:(NSURLResponse *)response data:(NSData *)dataerror:(NSError *__autoreleasing *)error{
    [self validateResponse:(NSHTTPURLResponse *)response data:data error:error];
    return data;
}


-(BOOL)validateResponse:(NSHTTPURLResponse *)response
                   data:(NSData *)data
                  error:(NSError *__autoreleasing *)error
{
    BOOL responseIsValid = YES;
    NSError *validationError = nil;
    
    if (response && [response isKindOfClass:[NSHTTPURLResponse class]]) {
        if (self.acceptableContentTypes && ![self.acceptableContentTypes containsObject:[response MIMEType]] && !([response MIMEType] == nil && [data length] == 0)) {
            if ([data length] > 0 && [response URL]) {
                //URL错误
                NSMutableDictionary *mutableUserInfo = [@{
                                                          NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedStringFromTable(@"Request failed: unacceptable content-type: %@", @"SAFNetworking", nil), [response MIMEType]],
                                                          NSURLErrorFailingURLErrorKey:[response URL],
                                                          SAFNetworkingOperationFailingURLResponseErrorKey:response,
                                                          } mutableCopy];
                if (data) {
                    //数据错误
                    mutableUserInfo[SAFNetworkingOperationFailingURLResponseDataErrorKey] = data;
                }
                validationError = SAFErorrWithUnderlyingError([NSError errorWithDomain:SAFURLResponseSerializationErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:mutableUserInfo], validationError);
            }
            responseIsValid = NO;
        }
        
        //网络返回错误status code ，区间不在200-300之间
        if (self.acceptableStatusCodes && ![self.acceptableStatusCodes containsIndex:(NSUInteger)response.statusCode] && [response URL]) {
            NSMutableDictionary *mutableUserInfo = [@{
                                                      NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedStringFromTable(@"Request failed: %@ (%ld)", @"SAFNetworking", nil), (long)response.statusCode],
                                                      NSURLErrorFailingURLErrorKey:[response URL],
                                                      SAFNetworkingOperationFailingURLResponseErrorKey:response,
                                                      } mutableCopy];
            if (data) {
                mutableUserInfo[SAFNetworkingOperationFailingURLResponseDataErrorKey] = data;
            }
            
            validationError = SAFErorrWithUnderlyingError([NSError errorWithDomain:SAFURLResponseSerializationErrorDomain code:NSURLErrorBadServerResponse userInfo:mutableUserInfo], validationError);
            responseIsValid = NO;
        }
    }
    
    if (error && !responseIsValid) {
        *error = validationError;
    }
    
    return responseIsValid;
}

#pragma -mark NSSecureCoding
+(BOOL)supportsSecureCoding{
    return YES;
}

#pragma -mark NSCoding
- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
    [aCoder encodeObject:self.acceptableContentTypes forKey:NSStringFromSelector(@selector(acceptableContentTypes))];
    [aCoder encodeObject:self.acceptableStatusCodes forKey:NSStringFromSelector(@selector(acceptableStatusCodes))];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder {
    self = [self init];
    if (!self) {
        return nil;
    }
    self.acceptableContentTypes = [aDecoder decodeObjectOfClass:[NSIndexSet class] forKey:NSStringFromSelector(@selector(acceptableContentTypes))];
    self.acceptableStatusCodes = [aDecoder decodeObjectOfClass:[NSIndexSet class] forKey:NSStringFromSelector(@selector(acceptableStatusCodes))];
    
    return self;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    SAFHTTPResponseSerializer *serializer = [[[self class] allocWithZone:zone] init];
    serializer.acceptableContentTypes = [self.acceptableContentTypes copyWithZone:zone];
    serializer.acceptableStatusCodes = [self.acceptableStatusCodes copyWithZone:zone];
    return serializer;
}

@end
