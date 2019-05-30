//
//  WebSocketManager.m
//  iosWebSocket
//
//  Created by yanglele on 2019/5/30.
//  Copyright © 2019 yanglele. All rights reserved.
//

#import "WebSocketManager.h"
#import "AFNetworking.h"

#define dispatch_main_async_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}

@interface WebSocketManager ()<SRWebSocketDelegate>

@property(nonatomic, strong) NSTimer *headerBeatTimer; //心跳定时器
@property(nonatomic, strong) NSTimer *networkTestingTimer; //没有网络的时候检测定时器
@property(nonatomic, assign) NSTimeInterval reConnectTime; //重连时间
@property(nonatomic, strong) NSMutableArray *sendDataArray; //存储要发送给服务器的数据
@property(nonatomic, assign) BOOL isActiveClose; //用于判断是否主动关闭长连接，如果是主动断开连接，连接失败的代理中，就不用执行 重新连接方法

@end


@implementation WebSocketManager

+(instancetype)shared{
    static WebSocketManager *__instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __instance = [[WebSocketManager alloc] init];
    });
    return __instance;
}

-(instancetype)init{
    self = [super init];
    if (self) {
        self.reConnectTime = 0;
        self.isActiveClose = NO;
        self.sendDataArray = [[NSMutableArray alloc] init];
    }
    return self;
}

//建立长连接
-(void)connectServer{
    if(self.webScoket){
        return;
    }
    
    self.webScoket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:@"ws://127.0.0.1:7272"]];
    self.webScoket.delegate = self;
    [self.webScoket open];
}

-(void)sendPing:(id)sender{
    NSLog(@"sendPing heart");
//    NSString *heart = @"heart";
    NSData *heartData = [[NSData alloc] initWithBase64EncodedString:@"heart" options:NSUTF8StringEncoding];
    [self.webScoket sendPing:heartData];
    //    [self.webScoket sendPing:nil error:NULL];
}

//关闭长连接
-(void)webSocketClose{
    self.isActiveClose = YES;
    self.isConnect = NO;
    self.socketStatus = WebSocketStatusDefault;
    
    if (self.webScoket) {
        [self.webScoket close];
        self.webScoket = nil;
    }
    //关闭心跳定时器
    [self destoryHeartBeat];
    //关闭网络检测定时器
    [self destoryNetWorkStartTesting];
}

#pragma mark socket delegate
//已经连接
-(void)webSocketDidOpen:(SRWebSocket *)webSocket{
    NSLog(@"已经连接,开启心跳");
    self.isConnect = YES;
    self.socketStatus = WebSocketStatusConnect;
    [self initHeartBeat];//开始心跳
}

//连接失败
-(void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error{
    NSLog(@"连接失败");
    self.isConnect = NO;
    self.socketStatus = WebSocketStatusDisConnect;
    NSLog(@"连接失败，这里可以实现掉线自动重连，要注意以下几点");
    NSLog(@"1.判断当前网络环境，如果断网了就不要连了，等待网络到来，在发起重连");
    NSLog(@"2.判断调用层是否需要连接，不需要的时候不k连接，浪费流量");
    NSLog(@"3.连接次数限制，如果连接失败了，重试10次左右就可以了");
    //判断网络环境
    if (AFNetworkReachabilityManager.sharedManager.networkReachabilityStatus == AFNetworkReachabilityStatusNotReachable) {
        //没有网络,开启网络监测定时器
        [self noNetWorkStartTesting];//开启网络检测定时器
    }else{
        [self reConnectServer];//连接失败，重新连接
    }
    
}

//接收消息
-(void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message{
    NSLog(@"接收消息 ---- %@", message);
    if (self.delegate && [self.delegate respondsToSelector:@selector(webSocketDidReceiveMessage:)]) {
        [self.delegate webSocketDidReceiveMessage:message];
    }
}

//关闭连接
-(void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean{
    self.isConnect = NO;
    if (self.isActiveClose) {
        self.socketStatus = WebSocketStatusDefault;
        return;
    }else{
        self.socketStatus = WebSocketStatusDisConnect;
    }
    NSLog(@"被关闭连接，code:%ld,reason:%@,wasClean:%d",code,reason,wasClean);
    
    [self destoryHeartBeat];  //断开时销毁心跳
    
    //判断网络
    if (AFNetworkReachabilityManager.sharedManager.networkReachabilityStatus == AFNetworkReachabilityStatusNotReachable) {
        //没有网络,开启网络监测定时器
        [self noNetWorkStartTesting];
    }else{
        //有网络
        NSLog(@"关闭网络");
        self.webScoket = nil;
        [self reConnectServer];
    }
}


/**
 接受服务端发生Pong消息，我们在建立长连接之后会建立与服务器端的心跳包
 心跳包是我们用来告诉服务端：客户端还在线，心跳包是ping消息，于此同时服务端也会返回给我们一个pong消息
 */
-(void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongData{
    NSLog(@"接受ping 数据  --> %@",pongData);
}

#pragma mark NSTimer
//初始化心跳
-(void)initHeartBeat{
    if (self.headerBeatTimer) {
        return;
    }
    [self destoryHeartBeat];
    dispatch_main_async_safe(^{
        self.headerBeatTimer = [NSTimer timerWithTimeInterval:10 target:self selector:@selector(senderheartBeat) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:self.headerBeatTimer forMode:NSRunLoopCommonModes];
    });
}

//重新连接
-(void)reConnectServer{
    
    //关闭之前的连接
    [self webSocketClose];
    
    //重连10次 2^10 = 1024
    if (self.reConnectTime > 1024) {
        self.reConnectTime = 0;
        return;
    }
    
    __weak typeof(self)ws = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.reConnectTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (ws.webScoket.readyState == SR_OPEN && ws.webScoket.readyState == SR_CONNECTING) {
            return ;
        }
        
        [ws connectServer];
        NSLog(@"重新连接......");
        if (ws.reConnectTime == 0) {//重连时间2的指数级增长
            ws.reConnectTime = 2;
        }else{
            ws.reConnectTime *= 2;
        }
    });
}

//发送心跳
-(void)senderheartBeat{
    NSLog(@"senderheartBeat");
    //和服务端约定好发送什么作为心跳标识，尽可能的减小心跳包大小
    __weak typeof (self) ws = self;
    dispatch_main_async_safe(^{
        if (ws.webScoket.readyState == SR_OPEN) {
            [ws sendPing:nil];
        }else if (ws.webScoket.readyState == SR_CONNECTING){
            NSLog(@"正在连接中");
            [ws reConnectServer];
        }else if (ws.webScoket.readyState == SR_CLOSED || ws.webScoket.readyState == SR_CLOSING){
            NSLog(@"断开，重连");
            [ws reConnectServer];
        }else{
            NSLog(@"没网络，发送失败，一旦断网 socket 会被我设置 nil 的");
        }
    });
}

//取消心跳
-(void)destoryHeartBeat{
    __weak typeof(self) ws = self;
    dispatch_main_async_safe(^{
        if (ws.headerBeatTimer) {
            [ws.headerBeatTimer invalidate];
            ws.headerBeatTimer = nil;
        }
    });
}

//没有网络的时候开始定时 -- 用于网络检测
-(void)noNetWorkStartTestingTimer{
    __weak typeof(self)ws = self;
    dispatch_main_async_safe(^{
        ws.networkTestingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(noNetWorkStartTesting) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:ws.networkTestingTimer forMode:NSDefaultRunLoopMode];
    });
}

//定时检测网络
-(void)noNetWorkStartTesting{
    if (AFNetworkReachabilityManager.sharedManager.networkReachabilityStatus != AFNetworkReachabilityStatusNotReachable) {
        //关闭网络检测定时器
        [self destoryNetWorkStartTesting];
        //重新连接
        [self reConnectServer];
    }
}
//取消网络检测
-(void)destoryNetWorkStartTesting{
    __weak typeof(self) ws = self;
    dispatch_main_async_safe(^{
        if (ws.networkTestingTimer) {
            [ws.networkTestingTimer invalidate];
            ws.networkTestingTimer = nil;
        }
    });
}

//发送数据给服务器
-(void)sendDataToServer:(NSString *)data{
    [self.sendDataArray addObject:data];
    
    //没有网络
    if(AFNetworkReachabilityManager.sharedManager.networkReachabilityStatus == AFNetworkReachabilityStatusNotReachable){
        //开启网络检测定时器
        [self noNetWorkStartTesting];
    }else{
        if (self.webScoket != nil) {
            //只有长连接OPEN开启状态才能调用send方法
            if (self.webScoket.readyState == SR_OPEN) {
                [self.webScoket send:data];
            }else if (self.webScoket.readyState == SR_CONNECTING){
                //正在连接
                NSLog(@"正在连接中，重连后会去自动同步数据");
            }else if(self.webScoket.readyState == SR_CLOSING || self.webScoket.readyState == SR_CLOSED){
                //调用 reConnectServer 方法重连,连接成功后 继续发送数据
                [self reConnectServer];
            }
        }else{
            [self connectServer];//连接服务器
        }
    }
}




@end
