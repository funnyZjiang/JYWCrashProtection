# JYWCrashProtection
降低和防止部分crash
利用消息转发机制，通过中间类JYCrashObject 来进行具体的消息转发，

不过 
+(BOOL)resolveClassMethod:(SEL)aSelector
方法目前还不能通过JYCrashObject方法来转发，具体的实现细节上应该还是同
+(BOOL)resolveInstanceMethod:(SEL)aSelector有区别
使用方法很简单，直接通过添加黑白名单即可
以下是示例代码
[JYCrashObject addToWhiteList:@"NSString"];
[[NSString class] performSelector:@selector(addObject:) withObject:nil afterDelay:0];
NSString *str = @"abc";
[str performSelector:@selector(removeObject:) withObject:nil];


