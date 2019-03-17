//
//  JYCrashObject.m
//  JYWKit
//
//  Created by zhengfeng1 on 2019/3/10.
//  Copyright © 2019年 蒋正峰. All rights reserved.
//

#import "JYCrashObject.h"
#import <objc/runtime.h>

@interface JYCrashObject ()
//用来记录每次崩溃产生时的类名与次数
@property (nonatomic, strong, readwrite) NSMutableDictionary *cachedList;
@end

#pragma mark -
#pragma mark ------ setup methods ------

static NSMutableArray * jywCrashWhiteList(){
    static NSMutableArray *jywCrashWhteList = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        jywCrashWhteList = [@[]mutableCopy];
    });
    return jywCrashWhteList;
}

static NSMutableArray * jywCrashBlackList(){
    static NSMutableArray *jywCrashBlackList = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        jywCrashBlackList = [@[]mutableCopy];
    });
    return jywCrashBlackList;
}

static NSArray * jywCrashHeadsList = nil;

/*
static NSMutableDictionary * jywCrashCachedDictionary(){
    static NSMutableDictionary *jywCrashCachedDic = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        jywCrashCachedDic = [@{}mutableCopy];
    });
    return jywCrashCachedDic;
}
*/

static dispatch_queue_t jyw_crash_object_queue(){
    
    static dispatch_queue_t jyw_crash_object_queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        jyw_crash_object_queue = dispatch_queue_create("jyw_crash_objcet_queue", DISPATCH_QUEUE_CONCURRENT);
    });
    return jyw_crash_object_queue;
}

static BOOL checkClsNameVaild(NSString *cls){
    return [[cls class] isSubclassOfClass:[NSString class]] && cls != nil && cls.length > 0;
}

static BOOL checkArrayVaild(NSArray <NSString *>*ary){
    if (ary == nil || ![[ary class]isSubclassOfClass:[NSArray class]]) {
        return NO;
    }
    return YES;
}

@implementation JYCrashObject

#pragma mark -
#pragma mark ------ list methods ------

+(void)add:(NSString *)clsName toList:(NSMutableArray *)ary{
    if (!checkClsNameVaild(clsName)) {
        NSLog(@"clsName is invaild");
        return;
    }
    if (!checkArrayVaild(ary)) {
        NSLog(@"ary is invaild");
        return;
    }
    dispatch_barrier_async(jyw_crash_object_queue(), ^{
        [ary addObject:clsName];
    });
}

+(void)remove:(NSString *)clsName fromList:(NSMutableArray *)ary{
    if (!checkClsNameVaild(clsName)) {
        NSLog(@"clsName is invaild");
        return;
    }
    if (!checkArrayVaild(ary)) {
        NSLog(@"ary is invaild");
        return;
    }
    if (![ary containsObject:clsName]) {
        NSLog(@"clsName : %@ doesnot belong to ary",clsName);
        return;
    }
    dispatch_barrier_async(jyw_crash_object_queue(), ^{
        [ary removeObject:clsName];
    });
}

+(void)whiteList:(NSArray *)whiteList{
    if (checkArrayVaild(whiteList)) {
        dispatch_barrier_async(jyw_crash_object_queue(), ^{
            [jywCrashWhiteList() addObjectsFromArray:whiteList];
        });
    }
}

+(void)addToWhiteList:(NSString *)clsName{
    [JYCrashObject add:clsName toList:jywCrashWhiteList()];
}

+(void)removeFromWhiteList:(NSString *)clsName{
    [JYCrashObject remove:clsName fromList:jywCrashWhiteList()];
}

+(void)blackList:(NSArray<NSString *> *)blackList{
    if (checkArrayVaild(blackList)) {
        dispatch_barrier_async(jyw_crash_object_queue(), ^{
            [jywCrashBlackList() addObjectsFromArray:blackList];
        });
    }
}

+(void)addToBlackList:(NSString *)clsName{
    [JYCrashObject add:clsName toList:jywCrashBlackList()];
}

+(void)removeFromBlackList:(NSString *)clsName{
    [JYCrashObject remove:clsName fromList:jywCrashBlackList()];
}

+(void)classHeadsList:(NSArray <NSString *>*)ary{
    if (checkArrayVaild(jywCrashHeadsList)) {
        return;
    }
    if (checkArrayVaild(ary)) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            jywCrashHeadsList = [ary copy];
        });
    }
}

+(BOOL)checkClassName:(NSString *)clsName inList:(NSArray<NSString *>*)ary{
    if (!checkClsNameVaild(clsName) || !checkArrayVaild(ary)) {
        return NO;
    }
    return [ary containsObject:clsName];
}

+(BOOL)checkInWhiteList:(NSString *)clsName{
    return [JYCrashObject checkClassName:clsName inList:jywCrashWhiteList()];
}

+(BOOL)checkInBlackList:(NSString *)clsName{
    return [JYCrashObject checkClassName:clsName inList:jywCrashBlackList()];
}

+(BOOL)checkInHeadsList:(NSString *)clsHead{
    if (checkClsNameVaild(clsHead) && checkArrayVaild(jywCrashHeadsList)) {
        __block BOOL result = NO;
        [jywCrashHeadsList enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([clsHead hasPrefix:obj]) {
                result = YES;
                *stop = YES;
            }
        }];
        return result;
    }
    return NO;
}

#pragma mark -
#pragma mark ----- message resolve ------

void jyw_forwardingTargetForSelector(id self,SEL _cmd){
    NSLog(@"%@ crashed",NSStringFromSelector(_cmd));
}

+(BOOL)resolveClassMethod:(SEL)sel{
    class_addMethod(object_getClass(self), sel, (IMP)jyw_forwardingTargetForSelector, "@:");
    [super resolveClassMethod:sel];
    return YES;
}

+(BOOL)resolveInstanceMethod:(SEL)sel{
    class_addMethod([self class], sel, (IMP)jyw_forwardingTargetForSelector, "@:");
    [super resolveInstanceMethod:sel];
    return YES;
}

-(id)forwardingTargetForSelector:(SEL)aSelector{
    id result = [super forwardingTargetForSelector:aSelector];
    return result;
}

@end

