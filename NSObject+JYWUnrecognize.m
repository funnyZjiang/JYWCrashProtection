//
//  NSObject+JYWUnrecognize.m
//  JYWKit
//
//  Created by zhengfeng1 on 2019/2/28.
//  Copyright © 2019年 蒋正峰. All rights reserved.
//

#import "NSObject+JYWUnrecognize.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "JYCrashObject.h"

static JYCrashObject *_crashObj(){
    static JYCrashObject *crash = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        crash = [JYCrashObject new];
    });
    return crash;
}

@implementation NSObject(JYWUnrecognize)

static inline void SwizzleClassMethod(Class c, SEL origSEL, SEL newSEL)
{
    Method origMethod = class_getClassMethod(c, origSEL);
    Method newMethod = class_getClassMethod(c, newSEL);
    
    if (class_addMethod(c, origSEL, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(c, newSEL, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}


BOOL jyw_unrecognizedResolveClassMethodSwizzle(Class aClass, SEL originalSelector, SEL swizzleSelector){
    Method orignalMethod = class_getClassMethod(aClass, originalSelector);
    Method swizzleMethod = class_getClassMethod(aClass, swizzleSelector);
    BOOL didAddMethod = class_addMethod(aClass,
                                        originalSelector,
                                        method_getImplementation(swizzleMethod),
                                        method_getTypeEncoding(swizzleMethod));
    if (didAddMethod) {
        class_replaceMethod(aClass,
                            swizzleSelector,
                            method_getImplementation(orignalMethod),
                            method_getTypeEncoding(orignalMethod));
    }else{
        method_exchangeImplementations(orignalMethod, swizzleMethod);
    }
    return YES;
}



BOOL jyw_unrecognizedForwardingTargetForSelectorSwizzle(Class aClass, SEL originalSelector, SEL swizzleSelector){
    Method orignalMethod = class_getInstanceMethod(aClass, originalSelector);
    Method swizzleMethod = class_getInstanceMethod(aClass, swizzleSelector);
    BOOL didAddMethod = class_addMethod(aClass,
                                        originalSelector,
                                        method_getImplementation(swizzleMethod),
                                        method_getTypeEncoding(swizzleMethod));
    if (didAddMethod) {
        class_replaceMethod(aClass,
                            swizzleSelector,
                            method_getImplementation(orignalMethod),
                            method_getTypeEncoding(orignalMethod));
    }else{
        method_exchangeImplementations(orignalMethod, swizzleMethod);
    }
    return YES;
}

+(void)load{
    
    jyw_unrecognizedResolveClassMethodSwizzle(
                                              object_getClass(self),
                                              @selector(resolveClassMethod:),
                                              @selector(jyw_resolveClassMethod:));
     
    jyw_unrecognizedForwardingTargetForSelectorSwizzle(
                                                       [self class],
                                                       @selector(forwardingTargetForSelector:),
                                                       @selector(jyw_forwardingTargetForSelector:)
                                                       );
}

/**
 *当容器类通过字面量来声明的时候，返回的class，也是带有__开头的，需要进一步判断
 *__NSCFConstantString __NSCFString __NSDictionary0 __NSDictionaryM __NSArray0 __NSArrayM __NSCFNumber
 **/
+(BOOL)isContainer:(Class)cls{
    NSArray *ary = @[@"__NSCFConstantString",@"__NSCFString",
                     @"__NSDictionary0",@"__NSDictionaryM",
                     @"__NSArray0",@"__NSArrayM",
                     @"__NSCFNumber"];
    NSString *classString = NSStringFromClass(cls);
    if (classString == nil) {
        return NO;
    }
    BOOL isContain = [ary containsObject:classString];
#if DEBUG
//    NSAssert(isContain, @"类型错误！！！请仔细检查！！！");
#endif
    return isContain;
}

+(BOOL)jyw_resolveClassMethod:(SEL)sel{
    if ([NSObject shouldForwardingToTarget:[self class]]) {
        class_addMethod(object_getClass(self), sel, (IMP)jyw_classMethodResolved, "@:");
    }
    return [NSObject jyw_resolveClassMethod:sel];;
}

void jyw_classMethodResolved(id self,SEL _cmd){
    NSLog(@"class Method %@ crashed",NSStringFromSelector(_cmd));
}

/**
 * 所有匹配q均区分大小写
 * 如果类在黑名单内，则肯定排除，优先级最高，精确匹配
 * 如果类在白名单内，则肯定显示，优先级次高，精确匹配
 * 如果类是系统默认生成的——以__开头的认为是系统内部类，默认排除，除非属于字面量生成的类，优先级再次，精确匹配
 * 最后检查是否在自定义的类名内，优先级最次，模糊匹配，只检查字符串是否包含其头部
 */
+(BOOL)shouldForwardingToTarget:(Class)cls{
    NSString *clsString = NSStringFromClass(cls);
    //是否属于黑名单，是的话，直接返回no
    if ([JYCrashObject checkInBlackList:clsString]) {
        return NO;
    }
    //是否属于白名单
    if ([JYCrashObject checkInWhiteList:clsString]) {
        return YES;
    }
    //是否是系统内部类，如果是，是否包含在字面量生成的容器类
    if ([clsString hasPrefix:@"_"]) {
        return [NSObject isContainer:cls];
    }
    //是否包含在类名字母内
    if ([JYCrashObject checkInHeadsList:clsString]) {
        return YES;
    }
    return NO;
}

-(id)jyw_forwardingTargetForSelector:(SEL)aSelector{
    if ([NSStringFromSelector(aSelector) isEqualToString:@"addObject:"]) {
        NSLog(@"%@",NSStringFromSelector(aSelector));
    }
    id result = [self jyw_forwardingTargetForSelector:aSelector];
    if (result) {
        return result;
    }
    BOOL shouldForwarding = [[self class]shouldForwardingToTarget:[self class]];
    if (!shouldForwarding) {
        return nil;
    }
    if (!result) {
       result = _crashObj();
    }
    NSLog(@"\n<<<<******* Attention: crash happend !! *******>>>>\n\ncrash detail: \n The Class    : %@ \n The Object   : %@ \n The Selector :%@\n The Thread Info: %@\n The Call Stack: %@\n\n<<<<******* Crash Info Finished !! *******>>>>\n \n \n ",NSStringFromClass([self class]),self, NSStringFromSelector(aSelector),[NSThread currentThread], [NSThread callStackSymbols]);
    return result;

}

@end
