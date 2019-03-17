//
//  JYCrashObject.h
//  JYWKit
//
//  Created by zhengfeng1 on 2019/3/10.
//  Copyright © 2019年 蒋正峰. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JYCrashObject : NSObject

/**
 *blacklist里的坚决不进流程
 */
+(void)blackList:(NSArray <NSString *>*)blackList;
+(void)addToBlackList:(NSString *)clsName;
+(void)removeFromBlackList:(NSString *)clsName;

/**
 * whitelist里的类名将会进行消息转发
 */
+(void)whiteList:(NSArray <NSString *>*)whiteList;
+(void)addToWhiteList:(NSString *)clsName;
+(void)removeFromWhiteList:(NSString *)clsName;

/*
 *白名单的补充数组，这里主要放一些类的头部标志，比如@[@"NS",@"UI",@"JY"]
 *如果命中该数组的内容，则也会予以转发
 *该数组初始化一次后便无法在修改
 */
+(void)classHeadsList:(NSArray <NSString *>*)ary;

+(BOOL)checkInWhiteList:(NSString *)clsName;
+(BOOL)checkInBlackList:(NSString *)clsName;
//只会比较头部，如果头部包含在内即认为命中
+(BOOL)checkInHeadsList:(NSString *)clsHead;



@end

