//
//  ViewController.m
//  iosWebSocket
//
//  Created by yanglele on 2019/5/30.
//  Copyright © 2019 yanglele. All rights reserved.
//

#import "ViewController.h"
#import "WebSocketManager.h"

@interface ViewController ()<WebSocketManagerDelegate>

@property (nonatomic, strong) UITextField *textField;
//@property (nonatomic, strong) WebSocketManager *socketManager;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self addViews];
    [WebSocketManager shared].delegate = self;
}

-(void)addViews{
    self.view.backgroundColor = [UIColor grayColor];
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(50, 100, 200, 40)];
    textField.borderStyle = UITextBorderStyleRoundedRect;
    textField.layer.masksToBounds = YES;
    textField.layer.cornerRadius = 12;
    self.textField = textField;
    [self.view addSubview:self.textField];
    
    UIButton *sendBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    sendBtn.frame = CGRectMake(50, 150, 100, 40);
    [sendBtn setTitle:@"发送" forState:UIControlStateNormal];
    sendBtn.layer.cornerRadius = 10;
    sendBtn.layer.masksToBounds = YES;
    sendBtn.backgroundColor = [UIColor orangeColor];
    [sendBtn addTarget:self action:@selector(sendInfo) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:sendBtn];
    
    UIButton *connectBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    connectBtn.frame = CGRectMake(50, 200, 100, 40);
    [connectBtn setTitle:@"连接" forState:UIControlStateNormal];
    connectBtn.layer.cornerRadius = 10;
    connectBtn.layer.masksToBounds = YES;
    connectBtn.backgroundColor = [UIColor orangeColor];
    [connectBtn addTarget:self action:@selector(startConnect) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:connectBtn];
    
    UIButton *closeConnectBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeConnectBtn.frame = CGRectMake(50, 250, 100, 40);
    [closeConnectBtn setTitle:@"断开" forState:UIControlStateNormal];
    closeConnectBtn.layer.cornerRadius = 10;
    closeConnectBtn.layer.masksToBounds = YES;
    closeConnectBtn.backgroundColor = [UIColor orangeColor];
    [closeConnectBtn addTarget:self action:@selector(closeConnect) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeConnectBtn];
    
    UIButton *pingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    pingBtn.frame = CGRectMake(50, 300, 100, 40);
    [pingBtn setTitle:@"sendPing" forState:UIControlStateNormal];
    pingBtn.layer.cornerRadius = 10;
    pingBtn.layer.masksToBounds = YES;
    pingBtn.backgroundColor = [UIColor orangeColor];
    [pingBtn addTarget:self action:@selector(sendPing) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:pingBtn];
    
}

-(void)sendInfo{
    [[WebSocketManager shared] sendDataToServer:self.textField.text];
}

-(void)startConnect{
    [[WebSocketManager shared] connectServer];
}

-(void)closeConnect{
    [[WebSocketManager shared] webSocketClose];
}

-(void)sendPing{
    
}

-(void)websocketManagerDidReceiveMessageWithString:(NSString *)string{
    NSLog(@"string %@",string);
}

@end
