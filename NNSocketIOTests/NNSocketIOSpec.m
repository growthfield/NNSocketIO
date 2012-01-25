#import "Kiwi.h"
#import "NNSocketIO.h"
#import "JSONKit.h"

SPEC_BEGIN(NNSocketIOSpec)
describe(@"NNSocketIO", ^{
    
    NSNumber* Yes = [NSNumber numberWithBool:YES];
    NSNumber* No = [NSNumber numberWithBool:NO];
    
    context(@"when client connects via http to", ^{
        __block NNSocketIO* io = nil;
        __block NNSocketIOOptions* opts = nil;
        __block NSNumber* onConnect = nil;
        beforeEach(^{
            onConnect = No;
            opts = [NNSocketIOOptions options];
            opts.retry = NO;
            io = [NNSocketIO io];
        });
        it(@"root namespace, connect event should be emitted", ^{
            NSURL* url = [NSURL URLWithString:@"http://localhost:8080"];
            id<NNSocketIOClient> root = [io connect:url options:opts];
            [root on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
            }];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
        });
        it(@"other namespace, connect event should be emitted", ^{
            NSURL* url = [NSURL URLWithString:@"http://localhost:8080/echo_message"];
            id<NNSocketIOClient> root = [io connect:url options:opts];
            [root on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
            }];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
        });
        it(@"namespaces which are created by 'connect' method, connect event should be emitted", ^{
            __block NSNumber* isConnected2 = No;
            NSURL* url1 = [NSURL URLWithString:@"http://localhost:8080"];
            NSURL* url2 = [NSURL URLWithString:@"http://localhost:8080/echo_message"];
            id<NNSocketIOClient> root = [io connect:url1 options:opts];
            id<NNSocketIOClient> other = [io connect:url2 options:opts];
            [root on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
            }];
            [other on:@"connect" listener:^(NNArgs* args) {
                isConnected2 = Yes;
            }];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&isConnected2) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
        });
        it(@"namespaces which are created by 'of' method, connect event should be emitted", ^{
            __block NSNumber* onConnect2 = No;
            NSURL* url = [NSURL URLWithString:@"http://localhost:8080"];
            id<NNSocketIOClient> root = [io connect:url options:opts];
            id<NNSocketIOClient> other = [root of:@"/echo_message"];
            [root on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
            }];
            [other on:@"connect" listener:^(NNArgs* args) {
                onConnect2 = Yes;
            }];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&onConnect2) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
        });
    });
    context(@"when retry disabled and client can't connect to", ^{
        __block NNSocketIO* io = nil;
        __block NNSocketIOOptions* opts = nil;
        __block NSNumber* onConnect = nil;
        __block NSNumber* onConnectFailed = nil;
        NSNumber* expectedAttempts = [NSNumber numberWithUnsignedInteger:0];
        NSNumber* expectedDelay = [NSNumber numberWithDouble:0];
        beforeEach(^{
            onConnect = No;
            onConnectFailed = No;
            opts = [NNSocketIOOptions options];
            opts.retry = NO;
            io = [NNSocketIO io];
        });
        it(@"root namespace, connect_failed event should be emitted", ^{
            NSURL* url = [NSURL URLWithString:@"http://localhost:9999"];
            id<NNSocketIOClient> root = [io connect:url options:opts];
            [root on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
            }];
            [root on:@"connect_failed" listener:^(NNArgs* args) {
                NSError* error = [args get:0];
                NSNumber* attempts = [args get:1];
                NSNumber* delay = [args get:2];
                [error shouldNotBeNil];
                [[attempts should] equal:expectedAttempts];
                [[delay should] equal:expectedDelay];
                onConnectFailed = Yes;
            }];
            [[theObject(&onConnectFailed) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[onConnect should] equal:No];
        });
        it(@"other namespace, connect_failed event should be emitted", ^{
            NSURL* url = [NSURL URLWithString:@"http://localhost:9999/echo_message"];
            id<NNSocketIOClient> other = [io connect:url options:opts];
            [other on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
            }];
            [other on:@"connect_failed" listener:^(NNArgs* args) {
                NSError* error = [args get:0];
                NSNumber* attempts = [args get:1];
                NSNumber* delay = [args get:2];
                [error shouldNotBeNil];
                [[attempts should] equal:theValue(0)];
                [[delay should] equal:theValue(0)];
                onConnectFailed = Yes;
            }];
            [[theObject(&onConnectFailed) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[onConnect should] equal:No];
        });
        it(@"namespaces which are created by 'connect' method, connect_failed event should be emitted", ^{
            __block NSNumber* onConnect2 = No;
            __block NSNumber* onConnectFailed2 = No;            
            NSURL* url1 = [NSURL URLWithString:@"http://localhost:9999"];
            NSURL* url2 = [NSURL URLWithString:@"http://localhost:9999/echo_message"];
            id<NNSocketIOClient> root = [io connect:url1 options:opts];
            id<NNSocketIOClient> other = [io connect:url2 options:opts];
            [root on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
            }];
            [root on:@"connect_failed" listener:^(NNArgs* args){
                NSError* error = [args get:0];
                NSNumber* attempts = [args get:1];
                NSNumber* delay = [args get:2];
                [error shouldNotBeNil];
                [[attempts should] equal:theValue(0)];
                [[delay should] equal:theValue(0)];
                onConnectFailed = Yes;
            }];
            [other on:@"connect" listener:^(NNArgs* args) {
                onConnect2 = Yes;
            }];
            [other on:@"connect_failed" listener:^(NNArgs* args) {
                NSError* error = [args get:0];
                NSNumber* attempts = [args get:1];
                NSNumber* delay = [args get:2];
                [error shouldNotBeNil];
                [[attempts should] equal:theValue(0)];
                [[delay should] equal:theValue(0)];
                onConnectFailed2 = Yes;
            }];
            [[theObject(&onConnectFailed) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&onConnectFailed2) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[onConnect should] equal:No];
            [[onConnect2 should] equal:No];
        });
        it(@"namespaces which are created by 'of' method, connect_failed event should be emitted", ^{
            __block NSNumber* onConnect2 = No;
            __block NSNumber* onConnectFailed2 = No;            
            NSURL* url = [NSURL URLWithString:@"http://localhost:9999"];
            id<NNSocketIOClient> root = [io connect:url options:opts];
            id<NNSocketIOClient> other = [root of:@"/echo_message"];
            [root on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
            }];
            [root on:@"connect_failed" listener:^(NNArgs* args){
                NSError* error = [args get:0];
                NSNumber* attempts = [args get:1];
                NSNumber* delay = [args get:2];
                [error shouldNotBeNil];
                [[attempts should] equal:theValue(0)];
                [[delay should] equal:theValue(0)];
                onConnectFailed = Yes;
            }];
            [other on:@"connect" listener:^(NNArgs* args) {
                onConnect2 = Yes;
            }];
            [other on:@"connect_failed" listener:^(NNArgs* args) {
                NSError* error = [args get:0];
                NSNumber* attempts = [args get:1];
                NSNumber* delay = [args get:2];
                [error shouldNotBeNil];
                [[attempts should] equal:theValue(0)];
                [[delay should] equal:theValue(0)];
                onConnectFailed2 = Yes;
            }];
            [[theObject(&onConnectFailed) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&onConnectFailed2) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[onConnect should] equal:No];
            [[onConnect2 should] equal:No];
        });
    });
    context(@"when retry enabled and client can't connect to", ^{
        __block NNSocketIO* io = nil;
        __block NNSocketIOOptions* opts = nil;
        __block NSNumber* onConnect = nil;
        __block NSNumber* onConnectFailed = nil;
        beforeEach(^{
            onConnect = No;
            onConnectFailed = No;
            opts = [NNSocketIOOptions options];
            opts.retry = YES;
            opts.retryDelay = 0.5;
            opts.retryMaxAttempts = 3;
            io = [NNSocketIO io];
        });
        it(@"root namespace, connect_failed should be emitted after retrying", ^{
            NSURL* url = [NSURL URLWithString:@"http://localhost:9999"];
            id<NNSocketIOClient> root = [io connect:url options:opts];
            [root on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
            }];
            [root on:@"connect_failed" listener:^(NNArgs* args) {
                NSError* error = [args get:0];
                NSNumber* attempts = [args get:1];
                NSNumber* delay = [args get:2];
                [error shouldNotBeNil];
                [[attempts should] equal:theValue(opts.retryMaxAttempts)];
                [[delay should] equal:theValue(2)];
                onConnectFailed = Yes;
            }];
            [[theObject(&onConnectFailed) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
            [[onConnect should] equal:No];
        });
        it(@"other namespace, connect_failed should be emitted after retrying", ^{
            NSURL* url = [NSURL URLWithString:@"http://localhost:9999/echo_message"];
            id<NNSocketIOClient> other = [io connect:url options:opts];
            [other on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
            }];
            [other on:@"connect_failed" listener:^(NNArgs* args) {
                NSError* error = [args get:0];
                NSNumber* attempts = [args get:1];
                NSNumber* delay = [args get:2];
                [error shouldNotBeNil];
                [[attempts should] equal:theValue(opts.retryMaxAttempts)];
                [[delay should] equal:theValue(2)];
                onConnectFailed = Yes;
            }];
            [[theObject(&onConnectFailed) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
            [[onConnect should] equal:No];
        });
        it(@"namespaces which are created by 'connect' method, connect_failed event should be emitted", ^{
            __block NSNumber* onConnect2 = No;
            __block NSNumber* onConnectFailed2 = No; 
            NSURL* url1 = [NSURL URLWithString:@"http://localhost:9999"];
            NSURL* url2 = [NSURL URLWithString:@"http://localhost:9999/echo_message"];
            id<NNSocketIOClient> root = [io connect:url1 options:opts];
            id<NNSocketIOClient> other = [io connect:url2 options:opts];
            [root on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
            }];
            [root on:@"connect_failed" listener:^(NNArgs* args) {
                NSError* error = [args get:0];
                NSNumber* attempts = [args get:1];
                NSNumber* delay = [args get:2];
                [error shouldNotBeNil];
                [[attempts should] equal:theValue(opts.retryMaxAttempts)];
                [[delay should] equal:theValue(2)];
                onConnectFailed = Yes;
            }];
            [other on:@"connect" listener:^(NNArgs* args) {
                onConnect2 = Yes;
            }];
            [other on:@"connect_failed" listener:^(NNArgs* args) {
                NSError* error = [args get:0];
                NSNumber* attempts = [args get:1];
                NSNumber* delay = [args get:2];
                [error shouldNotBeNil];
                [[attempts should] equal:theValue(opts.retryMaxAttempts)];
                [[delay should] equal:theValue(2)];
                onConnectFailed2 = Yes;
            }];
            [[theObject(&onConnectFailed) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
            [[onConnect should] equal:No];
            [[theObject(&onConnectFailed2) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
            [[onConnect2 should] equal:No];
        });
        it(@"namespaces which are created by 'of' method, connect_failed event should be emitted", ^{
            __block NSNumber* onConnect2 = No;
            __block NSNumber* onConnectFailed2 = No; 
            NSURL* url = [NSURL URLWithString:@"http://localhost:9999"];
            id<NNSocketIOClient> root = [io connect:url options:opts];
            id<NNSocketIOClient> other = [root of:@"/echo_message"];
            [root on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
            }];
            [root on:@"connect_failed" listener:^(NNArgs* args) {
                NSError* error = [args get:0];
                NSNumber* attempts = [args get:1];
                NSNumber* delay = [args get:2];
                [error shouldNotBeNil];
                [[attempts should] equal:theValue(opts.retryMaxAttempts)];
                [[delay should] equal:theValue(2)];
                onConnectFailed = Yes;
            }];
            [other on:@"connect" listener:^(NNArgs* args) {
                onConnect2 = Yes;
            }];
            [other on:@"connect_failed" listener:^(NNArgs* args) {
                NSError* error = [args get:0];
                NSNumber* attempts = [args get:1];
                NSNumber* delay = [args get:2];
                [error shouldNotBeNil];
                [[attempts should] equal:theValue(opts.retryMaxAttempts)];
                [[delay should] equal:theValue(2)];
                onConnectFailed2 = Yes;
            }];
            [[theObject(&onConnectFailed) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
            [[onConnect should] equal:No];
            [[theObject(&onConnectFailed2) shouldEventuallyBeforeTimingOutAfter(10.0)] beYes];
            [[onConnect2 should] equal:No];
        });
    });
    context(@"when client disconnects", ^{
        __block NNSocketIO* io = nil;
        __block NNSocketIOOptions* opts = nil;
        __block NSNumber* onConnect = nil;
        __block NSNumber* onDisconnect = nil;
        __block NSNumber* onReconnecting = nil;
        __block NSNumber* onConnectOther = nil;
        __block NSNumber* onDisconnectOther = nil;
        __block NSNumber* onReconnectingOther = nil;
        beforeEach(^{
            onConnect = No;
            onDisconnect = No;
            onReconnecting = No;
            onConnectOther = No;
            onDisconnectOther = No;
            onReconnectingOther = No;
            opts = [NNSocketIOOptions options];
            io = [NNSocketIO io];
        });
        it(@"root namespace and connection recovery is disabled, disconnect event should be emitted to all namespaces", ^{
            NSURL* url = [NSURL URLWithString:@"http://localhost:8080"];
            opts.connectionRecovery = NO;
            id<NNSocketIOClient> root = [io connect:url options:opts];
            [root on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                [root disconnect];
            }];
            [root on:@"disconnect" listener:^(NNArgs* args) {
                onDisconnect = Yes;
            }];
            id<NNSocketIOClient> other = [root of:@"/echo_message"];
            [other on:@"connect" listener:^(NNArgs* args) {
                onConnectOther = Yes;
            }];
            [other on:@"disconnect" listener:^(NNArgs* args) {
                onDisconnectOther = Yes;                    
            }];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&onDisconnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&onConnectOther) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&onDisconnectOther) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
        });
        it(@"non root namespace and connection recovery is disable, disconnect event should be only emitted to its namespace", ^{
            NSURL* url = [NSURL URLWithString:@"http://localhost:8080"];
            opts.connectionRecovery = NO;
            id<NNSocketIOClient> root = [io connect:url options:opts];
            [root on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
            }];
            [root on:@"disconnect" listener:^(NNArgs* args) {
                onDisconnect = Yes;
            }];
            id<NNSocketIOClient> other = [root of:@"/echo_message"];
            [other on:@"connect" listener:^(NNArgs* args) {
                onConnectOther = Yes;
                [other disconnect];
            }];
            [other on:@"disconnect" listener:^(NNArgs* args) {
                onDisconnectOther = Yes;                    
            }];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&onDisconnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beNo];
            [[theObject(&onConnectOther) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&onDisconnectOther) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
        });
        it(@"root namespace and connection recovery is enabled, connection should not be recovered", ^{
            NSURL* url = [NSURL URLWithString:@"http://localhost:8080"];
            opts.connectionRecovery = YES;
            id<NNSocketIOClient> root = [io connect:url options:opts];
            [root on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
                [root disconnect];
            }];
            [root on:@"disconnect" listener:^(NNArgs* args) {
                onDisconnect = Yes;
            }];
            id<NNSocketIOClient> other = [root of:@"/echo_message"];
            [other on:@"connect" listener:^(NNArgs* args) {
                onConnectOther = Yes;
            }];
            [other on:@"disconnect" listener:^(NNArgs* args) {
                onDisconnectOther = Yes;                    
            }];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&onDisconnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&onConnectOther) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&onDisconnectOther) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
        });
    });
    context(@"when server disconnects", ^{
        __block NNSocketIO* io = nil;
        __block NNSocketIOOptions* opts = nil;
        __block NSNumber* onConnect = nil;
        __block NSNumber* onDisconnect = nil;
        __block NSNumber* onReconnecting = nil;
        __block NSNumber* onConnectOther = nil;
        __block NSNumber* onDisconnectOther = nil;
        __block NSNumber* onReconnectingOther = nil;
        beforeEach(^{
            onConnect = No;
            onDisconnect = No;
            onReconnecting = No;
            onConnectOther = No;
            onDisconnectOther = No;
            onReconnectingOther = No;
            opts = [NNSocketIOOptions options];
            io = [[NNSocketIO alloc] init];
        });
        it(@"client and connection recovery is enabled, disconnect event should be emitted to all namespaces", ^{
            __block NSNumber* onReconnect = No;
            __block NSNumber* onReconnectOther = No;
            __block int onConnectCount = 0;
            __block int onConnectOtherCount = 0; 
            __block int onDisconnectCount = 0;
            __block int onDisconnectOtherCount = 0;
            NSURL* url = [NSURL URLWithString:@"http://localhost:8080"];
            opts.connectionRecovery = YES;
            id<NNSocketIOClient> root = [io connect:url options:opts];
            [root on:@"connect" listener:^(NNArgs* args) {
                if (onConnectCount > 0) {
                    onReconnect = Yes;
                }
                onConnectCount++;
            }];
            [root on:@"disconnect" listener:^(NNArgs* args) {
                onDisconnectCount++;
            }];
            id<NNSocketIOClient> other = [root of:@"/client_force_disconnect"];
            [other on:@"connect" listener:^(NNArgs* args) {
                if (onConnectOtherCount == 0) {
                    [other emit:@"bye"];                    
                } else {
                    onReconnectOther = Yes;
                }
                
                onConnectOtherCount++;
            }];
            [other on:@"disconnect" listener:^(NNArgs* args) {
                onDisconnectOtherCount++;
            }];
            [[theObject(&onReconnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&onReconnectOther) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theValue(onConnectCount) should] equal:theValue(2)];
            [[theValue(onConnectOtherCount) should] equal:theValue(2)];
            [[theValue(onDisconnectCount) should] equal:theValue(1)];
            [[theValue(onDisconnectOtherCount) should] equal:theValue(1)];            
        });
         
    });
    context(@"message", ^{
        __block id<NNSocketIOClient> ch = nil;
        __block NSNumber* isConnected = nil;
        __block NSString* receiveData = nil;
        beforeEach(^{
            NSURL* url = [NSURL URLWithString:@"http://localhost:8080/echo_message"];
            NNSocketIOOptions* opts = [NNSocketIOOptions options];
            opts.retry = NO;
            opts.connectionRecovery = NO;
            ch = [[NNSocketIO io] connect:url options:opts];
            isConnected = No;
            receiveData = nil;
        });
        afterEach(^{
            [ch disconnect]; 
        });
        it(@"should be sent and got echo message", ^{
            NSString* msg = @"Hello world";
            [ch on:@"connect" listener:^(NNArgs* args) {
                isConnected = Yes;
                [ch send:msg];
            }];
            [ch on:@"message" listener:^(NNArgs* args) {
                receiveData = [args get:0];
                [[receiveData should] equal:msg];
            }];
            [[theObject(&isConnected) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receiveData) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];
        });
         it(@"nil should be sent and got echo message", ^{
             NSString* msg = nil;
             __block NSNumber* isReceived = nil; 
             [ch on:@"connect" listener:^(NNArgs* args) {
                 isConnected = Yes;
                 [ch send:msg];
             }];
             [ch on:@"message" listener:^(NNArgs* args) {
                 receiveData = [args get:0];
                 [receiveData shouldBeNil];
                 isReceived = Yes;
             }];
             [[theObject(&isConnected) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
             [[theObject(&isReceived) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
         });
         it(@"empty should be sent and got echo message", ^{
             NSString* msg = @"";
             __block NSNumber* isReceived = nil; 
             [ch on:@"connect" listener:^(NNArgs* args) {
                 isConnected = Yes;
                 [ch send:msg];
             }];
             [ch on:@"message" listener:^(NNArgs* args) {
                 receiveData = [args get:0];
                 [receiveData shouldBeNil];
                 isReceived = Yes;
             }];
             [[theObject(&isConnected) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
             [[theObject(&isReceived) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
         });
         it(@"string should be sent and got ack message", ^{
             __block NSNumber* isAcked = No;
            NSString* msg = @"Ack please";
            [ch on:@"connect" listener:^(NNArgs* args) {
                isConnected = Yes;
                [ch send:msg listener:^(NNArgs* ack){
                    isAcked = Yes;
                }];
            }];
            [ch on:@"message" listener:^(NNArgs* args) {
                receiveData = [args get:0];
                [[receiveData should] equal:msg];
            }];
            [[theObject(&isConnected) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&isAcked) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receiveData) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];
        });
    });
    context(@"client ack message", ^{
        __block id<NNSocketIOClient> ch = nil;
        __block NSNumber* isConnected = nil;
        __block NSNumber* isSentAck = nil;
        __block NSUInteger msgCnt = 0;
        beforeEach(^{
            NSURL* url = [NSURL URLWithString:@"http://localhost:8080/client_ack_message"];
            NNSocketIOOptions* opts = [NNSocketIOOptions options];
            opts.retry = NO;
            opts.connectionRecovery = NO;
            ch = [[NNSocketIO io ]connect:url options:opts];
            isConnected = No;
            isSentAck = No;
            msgCnt = 0;
        });
        afterEach(^{
            [ch disconnect]; 
        });
        it(@"should be sent automatically", ^{
            [ch on:@"connect" listener:^(NNArgs* args) {
                isConnected = Yes;
                [ch send:@"foo"];
            }];
            [ch on:@"message" listener:^(NNArgs* args) {
                NSString* msg = [args get:0];
                msgCnt++;
                if (msgCnt == 1) {
                    [[msg should] equal:@"got message"];                    
                } else if (msgCnt == 2) {
                    [[msg should] equal:@"got ack"]; 
                    isSentAck = Yes;
                }
            }];
            [[theObject(&isConnected) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&isSentAck) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];

        });
    });
    context(@"json", ^{
        __block id<NNSocketIOClient> ch = nil;
        __block NSNumber* isConnected = nil;
        __block NSString* receiveData = nil;
        beforeEach(^{
            NSURL* url = [NSURL URLWithString:@"http://localhost:8080/echo_json"];
            NNSocketIOOptions* opts = [NNSocketIOOptions options];
            opts.retry = NO;
            opts.connectionRecovery = NO;
            ch = [[NNSocketIO io] connect:url options:opts];
            isConnected = No;
            receiveData = nil;
        });
        afterEach(^{
            [ch disconnect]; 
        });
        it(@"NSDictionary should be sent as json and got echo json", ^{
            //NSString* msg = @"{\"name\":\"hoge\", \"value\":\"fuga\"}";
            NSDictionary* json = [NSDictionary dictionaryWithObjectsAndKeys:@"hoge", @"name", @"fuga", @"value",nil];
            [ch on:@"connect" listener:^(NNArgs* args) {
                isConnected = Yes; 
                [ch.json send:json];
            }];
            [ch on:@"message" listener:^(NNArgs* args) {
                receiveData = [args get:0];
                [[receiveData should] equal:json];
            }];
            [[theObject(&isConnected) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receiveData) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];
        });
        it(@"NSArray should be sent as json and got echo json", ^{
            NSDictionary* json = [NSArray arrayWithObjects:@"hoge", @"fuga", nil];
            [ch on:@"connect" listener:^(NNArgs* args) {
                isConnected = Yes; 
                [ch.json send:json];
            }];
            [ch on:@"message" listener:^(NNArgs* args) {
                receiveData = [args get:0];
                [[receiveData should] equal:json];
            }];
            [[theObject(&isConnected) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receiveData) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];
        });
        it(@"should be sent and got ack message", ^{
            __block NSNumber* isAcked = No;
            NSArray* msg = [NSArray arrayWithObjects:@"ack", @"please", nil];
            [ch on:@"connect" listener:^(NNArgs* args) {
                isConnected = Yes;
                [ch.json send:msg listener:^(NNArgs* ack) {
                    isAcked = Yes;
                }];
            }];
            [ch on:@"message" listener:^(NNArgs* args) {
                receiveData = [args get:0];
                [[receiveData should] equal:msg];
            }];
            [[theObject(&isConnected) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&isAcked) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receiveData) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];
        });
    });
    context(@"event", ^{
        __block id<NNSocketIOClient> ch = nil;
        __block NSNumber* isConnected = nil;
        __block id receiveData = nil;
        beforeEach(^{
            NSURL* url = [NSURL URLWithString:@"http://localhost:8080/event"];
            NNSocketIOOptions* opts = [NNSocketIOOptions options];
            opts.retry = NO;
            opts.connectionRecovery = NO;
            ch = [[NNSocketIO io] connect:url options:opts];
            isConnected = No;
            receiveData = nil;
        });
        afterEach(^{
            [ch disconnect]; 
        });
        it(@"JSON object should be sent and got response event", ^{
            NSDictionary* profile = [NSDictionary dictionaryWithObjectsAndKeys:@"taro", @"name", [NSNumber numberWithInt:20], @"age",nil];
            NSDictionary* welcome = [NSDictionary dictionaryWithObjectsAndKeys:@"taro", @"hello", nil];
            [ch on:@"connect" listener:^(NNArgs* args) {
                isConnected = Yes; 
                [ch emit:@"profile" args:[[NNArgs args] add:profile]];
            }];
            [ch on:@"welcome" listener:^(NNArgs* args) {
                receiveData = [args get:0];
                [[receiveData should] equal:welcome];
            }];
            [[theObject(&isConnected) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receiveData) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];
        });
        it(@"JSON object should be sent and got ack json", ^{
            NSDictionary* profile = [NSDictionary dictionaryWithObjectsAndKeys:@"taro", @"name", [NSNumber numberWithInt:20], @"age",nil];
            NSDictionary* welcome = [NSDictionary dictionaryWithObjectsAndKeys:@"taro", @"hello", nil];
            [ch on:@"connect" listener:^(NNArgs* args) {
                isConnected = Yes; 
                [ch emit:@"profile_ack" args:[[NNArgs args] add:profile] listener:^(NNArgs* ack) {
                    receiveData = [ack get:0];
                    [[receiveData should] equal:welcome];                    
                }];
            }];
            [[theObject(&isConnected) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receiveData) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];            
        });
        it(@"JSON array should be sent and got response event", ^{
            NSString* tweet = @"hello!";
            [ch on:@"connect" listener:^(NNArgs* args) {
                isConnected = Yes;
                [ch emit:@"tweet" args:[[[NNArgs args] add:@"I said"] add:tweet]];
            }];
            [ch on:@"tweet_echo" listener:^(NNArgs* args) {
                [[[args get:0] should] equal:@"You said"];
                receiveData = [args get:1];
                [[receiveData should] equal:tweet];                    
            }];
            [[theObject(&isConnected) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receiveData) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];            
        });
        it(@"JSON array should be sent and got got ack json", ^{
            NSString* tweet = @"hello!";
            [ch on:@"connect" listener:^(NNArgs* args) {
                isConnected = Yes;
                [ch emit:@"tweet_ack" args:[[[NNArgs args] add:@"I said"] add:tweet] listener:^(NNArgs* args) {
                    [[[args get:0] should] equal:@"You said"];
                    receiveData = [args get:1];
                    [[receiveData should] equal:tweet];                                        
                }];
            }];
            [[theObject(&isConnected) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&receiveData) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];            
        });
    });
    context(@"client ack event", ^{
        __block id<NNSocketIOClient> ch = nil;
        __block NSNumber* isConnected = nil;
        beforeEach(^{
            NSURL* url = [NSURL URLWithString:@"http://localhost:8080/client_ack_event"];
            NNSocketIOOptions* opts = [NNSocketIOOptions options];
            opts.retry = NO;
            opts.connectionRecovery = NO;
            ch = [[NNSocketIO io] connect:url options:opts];
            isConnected = No;
        });
        afterEach(^{
            [ch disconnect]; 
        });
        it(@"should be able to sent explicitly", ^{
            __block NSString* name = nil;
            [ch on:@"connect" listener:^(NNArgs* args) {
                isConnected = [NSNumber numberWithBool:YES];
            }];
            [ch on:@"tell me your name" listener:^(NNArgs* args) {
                NNSocketIOAck ack = [args get:0];
                ack([[NNArgs args] add:@"foo"]);
            }];
            [ch on:@"i know your name" listener:^(NNArgs* args) {
                 NSDictionary* json = [args get:0];
                [json shouldNotBeNil];
                name = [json objectForKey:@"name"];
                [[name should] equal:@"foo"];
            }];
            [[theObject(&isConnected) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[theObject(&name) shouldEventuallyBeforeTimingOutAfter(3.0)] beNonNil];
            
        });        
    });
    context(@"when client connects to protected server", ^{
        __block NNSocketIO* io = nil;
        __block NNSocketIOOptions* opts = nil;
        __block NSNumber* onConnect = nil;
        __block NSNumber* onConnectFailed = nil;
        beforeEach(^{
            onConnect = No;
            onConnectFailed = No;
            opts = [NNSocketIOOptions options];
            opts.retry = NO;
            io = [NNSocketIO io];
        });
        it(@"global authorization should be failed", ^{
            NSURL* url = [NSURL URLWithString:@"http://localhost:8081"];
            id<NNSocketIOClient> root = [io connect:url options:opts];
            [root on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
            }];
            [root on:@"connect_failed" listener:^(NNArgs* args) {
                onConnectFailed = Yes;
            }];
            [[theObject(&onConnectFailed) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[onConnect should] equal:No];
        });
        it(@"global authorization should be succeed", ^{
            NSHTTPCookieStorage* storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
            NSURL* url = [NSURL URLWithString:@"http://localhost:8081"];
            NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"localhost", NSHTTPCookieDomain,
                                  [NSNumber numberWithInt:8081], NSHTTPCookiePort,
                                  @"/", NSHTTPCookiePath,
                                  @"testauth", NSHTTPCookieName,
                                  @"1", NSHTTPCookieValue,
                                  [NSDate dateWithTimeIntervalSinceNow:10], NSHTTPCookieMaximumAge,
                                  nil];
            NSHTTPCookie* cookie = [NSHTTPCookie cookieWithProperties:dict];
            [storage setCookie:cookie];
            id<NNSocketIOClient> root = [io connect:url options:opts];
            [root on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
            }];
            [root on:@"connect_failed" listener:^(NNArgs* args) {
                onConnectFailed = Yes;
            }];
            [[theObject(&onConnect) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[onConnectFailed should] equal:No];
        });
        it(@"namespace authorization should be failed", ^{
            NSURL* url = [NSURL URLWithString:@"http://localhost:8080/auth_error"];
            id<NNSocketIOClient> nsp = [io connect:url options:opts];
            [nsp on:@"connect" listener:^(NNArgs* args) {
                onConnect = Yes;
            }];
            [nsp on:@"connect_failed" listener:^(NNArgs* args) {
                onConnectFailed = Yes;
            }];
            [[theObject(&onConnectFailed) shouldEventuallyBeforeTimingOutAfter(3.0)] beYes];
            [[onConnect should] equal:No];
        });
    });
});

SPEC_END