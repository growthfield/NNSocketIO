#import "NNSocketIOSocket.h"
#import "NNSocketIO.h"
#import "NNSocketIOParser.h"
#import "NNSocketIODebug.h"
#import "NNSocketIONamespace.h"
#import "NNWebSocket.h"
#import "NNReachability.h"

#define SHARED_STATE_METHOD() \
+ (NNSocketIOSocketState*)sharedState \
{ \
    static id instance_ = nil; \
    static dispatch_once_t once; \
    dispatch_once(&once, ^{ \
        instance_ = [[self alloc] init]; \
    }); \
    return instance_; \
}

// NNSocketIOSocket =================================================
@interface NNSocketIOSocket()
@property(nonatomic, assign) NNSocketIOSocketState* state;
@property(nonatomic, retain) NSMutableDictionary* namespaces;
@property(nonatomic, retain) NNWebSocket* websocket;
@property(nonatomic, assign) NSTimeInterval retryDelay;
@property(nonatomic, assign) NSUInteger retryAttempts;
@property(nonatomic, assign) NSUInteger connectionRecoveryAttempts;
@property(nonatomic, retain) NSMutableArray* sendPacketBuffer;
@property(nonatomic, assign) BOOL disconnectionClientInitiated;
@property(nonatomic, retain) NSError* disconnectionReason;
@property(nonatomic, retain) NNDispatch* disconnectTimeoutDispatch;
@property(nonatomic, assign) BOOL isNetworkAvailable;
- (void)connect;
- (void)publish:(NSString*) eventName;
- (void)publish:(NSString*) eventName args:(NNArgs*)args;
- (void)changeState:(NNSocketIOSocketState*)newState;
- (NNWebSocket*)createWebSocket:(NSString*)sessionId;
- (void)didReconnect;
- (void)didConnect;
- (void)didConnectFailed:(NSError*)error;
- (void)didDisconnect;
- (void)didOpen;
- (void)didClose:(NSError*)error;
- (void)didReceivePacket:(NNSocketIOPacket*)packet;
- (void)didChangeNetworkReachability:(NSNotification*)notification;
@end

// Abstract states =================================================
@interface NNSocketIOSocketState : NSObject
- (void)didEnter:(NNSocketIOSocket*)ctx;
- (void)didExit:(NNSocketIOSocket*)ctx;
- (void)didOpen:(NNSocketIOSocket*)ctx;
- (void)didOpenFailed:(NNSocketIOSocket*)ctx error:(NSError*)error;
- (void)didClose:(NNSocketIOSocket*)ctx error:(NSError*)error;
- (void)didReceivePacket:(NNSocketIOSocket*)ctx packet:(NNSocketIOPacket*)packet;
- (void)connect:(NNSocketIOSocket*)ctx;
- (void)disconnect:(NNSocketIOSocket*)ctx;
- (void)sendPacket:(NNSocketIOSocket*)ctx packet:(NNSocketIOPacket*)packet;
@end

// Concrete states =================================================
@interface NNSocketIOSocketStateDisconnected : NNSocketIOSocketState
+ (id)sharedState;
@end
@interface NNSocketIOSocketStateConnecting : NNSocketIOSocketState
+ (id)sharedState;
- (void)handshake:(NNSocketIOSocket*)ctx;
- (void)retry:(NNSocketIOSocket*)ctx;
- (void)failWithCode:(NNSocketIOSocket*)ctx code:(NNSocketIOErrors)code;
- (void)fail:(NNSocketIOSocket*)ctx error:(NSError*)error;
@end
@interface NNSocketIOSocketStateConnected : NNSocketIOSocketState
+ (id)sharedState;
@end
@interface NNSocketIOSocketStateDisconnecting : NNSocketIOSocketState
+ (id)sharedState;
@end

// NNSocketIOSocket impl =================================================
@implementation NNSocketIOSocket
@synthesize state = state_;
@synthesize namespaces = namespaces_;
@synthesize websocket = websocket_;
@synthesize options = options_;
@synthesize secure = secure_;
@synthesize host = host_;
@synthesize port = port_;
@synthesize sessionId = sessionId_;
@synthesize retryDelay = retryDelay_;
@synthesize retryAttempts = retryAttempts_;
@synthesize connectionRecoveryAttempts = connectionRecoveryAttempts_;
@synthesize sendPacketBuffer = sendPacketBuffer_;
@synthesize disconnectionClientInitiated = disconnectionClientInitiated_;
@synthesize disconnectionReason = disconnectionReason_;
@synthesize disconnectTimeoutDispatch = disconnectTimeoutDispatch_;
@synthesize isNetworkAvailable = isNetworkAvailable_;
- (id)initWithURL:(NSURL *)url options:(NNSocketIOOptions*)options
{
    TRACE();
    self = [super init];
    if (self) {
        self.isNetworkAvailable = YES;
        self.state = [NNSocketIOSocketStateDisconnected sharedState];
        self.namespaces = [NSMutableDictionary dictionary];
        self.options = options;
        self.secure = [@"https" isEqualToString:url.scheme] ? YES : NO;
        self.host = url.host;
        NSInteger p;
        if (url.port) {
            p = [url.port intValue];
        } else {
            p = self.secure ? 443 : 80;
        }
        self.port = p;
        self.retryDelay = options.retryDelay;
        self.retryAttempts = 0;
        self.sendPacketBuffer= [NSMutableArray array];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeNetworkReachability:) name:NNREACHABILITY_CHANGED_NOTIFICATION object:nil];
        [self connect];
    }
    TRACE(@"socket created %@", self);
    return self;
}
- (void)dealloc
{
    TRACE();
    self.options = nil;
    self.host = nil;
    self.sessionId = nil;
    self.namespaces = nil;
    self.sendPacketBuffer = nil;
    self.websocket = nil;
    [super dealloc];

}
- (NNSocketIONamespace*)of:(NSString*)name
{
    TRACE();
    NNSocketIONamespace* nsp = nil;
    nsp = [self.namespaces objectForKey:name];
    if (!nsp) {
        nsp = [NNSocketIONamespace namespaceWithSocket:self name:name];
        [self.namespaces setObject:nsp forKey:name]; 
        if (name.length > 0) {
            NNSocketIOPacket* packet = [NNSocketIOPacket packet:NNSocketIOMessageTypeConnect];
            [nsp packet:packet];
        }
    }
    return nsp;
}
- (void)changeState:(NNSocketIOSocketState*)newState
{
    TRACE();
    NNSocketIOSocketState* oldState = state_;
    state_ = newState;
    [oldState didExit:self];
    [newState didEnter:self];
}
- (void)sendPacket:(NNSocketIOPacket *)packet
{
    TRACE();
    [self.state sendPacket:self packet:packet];
}
- (NNWebSocket*)createWebSocket:(NSString*)sessionId
{
    TRACE();
    NSMutableString* u = [NSMutableString string];
    [u appendString:self.secure ? @"wss" : @"ws"];
    [u appendFormat:@"://"];
    [u appendFormat:@"%@:%d", self.host, self.port];
    [u appendFormat:@"/%@/%d/", self.options.resource, self.options.protocolVersion];
    [u appendFormat:@"websocket/%@/", sessionId];
    NSURL* url = [NSURL URLWithString:u];
    NNWebSocketOptions* wsopts = [NNWebSocketOptions options];
    wsopts.enableBackgroundingOnSocket = self.options.enableBackgroundingOnSocket;
    wsopts.tlsSettings = self.options.tlsSettings;
    NNWebSocket* websocket = [[[NNWebSocket alloc] initWithURL:url origin:nil protocols:nil options:wsopts] autorelease];
    self.websocket = websocket;
    self.sessionId = sessionId;
    __block NNSocketIOSocket* self_ = self;
    [websocket on:@"connect" listener:^(NNArgs* args) {
        [self_.state didOpen:self_];
    }];
    [websocket on:@"connect_failed" listener:^(NNArgs* args) {
        NSError* error = [args get:0];
        [self_.state didOpenFailed:self_ error:error];
    }];
    [websocket on:@"disconnect" listener:^(NNArgs* args) {
        //NSNumber* clientInitiated = [args get:0];
        //NSNumber* status = [args get:1];
        NSError* error = [args get:2];
        [self_.state didClose:self_ error:error];
    }];
    [websocket on:@"receive" listener:^(NNArgs* args) {
        NNWebSocketFrame* frame = [args get:0];
        if (!frame.opcode == NNWebSocketFrameOpcodeText) {
            return;
        }
        NNSocketIOPacket* packet = [NNSocketIOParser decodePacket:frame.payloadString];
        if (packet) {
            [self_.state didReceivePacket:self_ packet:packet];
        }
    }];
    return websocket;
}
- (void)connect
{
    TRACE();
    [self.state connect:self];
}
- (void)disconnect
{
    TRACE();
    [self.state disconnect:self];
    
}
- (void)publish:(NSString*)eventName
{
    TRACE();
    [self publish:eventName args:nil];
}

- (void)publish:(NSString*)eventName args:(NNArgs*)args
{
    TRACE();
    [self.namespaces enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL* stop) {
        NNSocketIONamespace* nsp = (NNSocketIONamespace*)obj;
        [nsp $emit:eventName args:args];
    }];
}
- (void)didConnect
{
    TRACE();
    if (self.connectionRecoveryAttempts > 0) {
        [self didReconnect];
    }
}
- (void)didConnectFailed:(NSError *)error
{
    TRACE();
    NSNumber* attempts = [NSNumber numberWithUnsignedInteger:self.retryAttempts];
    NSNumber* delay = [NSNumber numberWithDouble:self.retryAttempts ? self.retryDelay : 0];
    [self publish:@"connect_failed" args:[[[[NNArgs args] add:error] add:attempts] add:delay]];
}
- (void)didReconnect
{
    TRACE();
    [self publish:@"reconnect"];
    [self.namespaces enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL* stop) {
        NSString* name = (NSString*)key;
        if (name.length > 0) {
            NNSocketIONamespace* nsp = (NNSocketIONamespace*)obj;
            NNSocketIOPacket* packet = [NNSocketIOPacket packet:NNSocketIOMessageTypeConnect];
            [nsp packet:packet];
        }
    }];
}
- (void)didDisconnect
{
    TRACE();
    if (self.disconnectionReason) {
        [self publish:@"error" args:[[NNArgs args] add:self.disconnectionReason]];
    }
    [self publish:@"disconnect"];
    if (!self.disconnectionClientInitiated && self.options.connectionRecovery && self.isNetworkAvailable) {
        if (self.connectionRecoveryAttempts < NSUIntegerMax) {
            self.connectionRecoveryAttempts++;
        }
        [self changeState:[NNSocketIOSocketStateConnecting sharedState]];
    }
}
- (void)didOpen
{
    TRACE();
    // Do nothing.
}
- (void)didClose:(NSError *)error
{
    TRACE();
    // Do nothing.
}
- (void)didReceivePacket:(NNSocketIOPacket *)packet
{
    TRACE();
    [[self of:packet.endpoint] onPacket:packet];
}
- (void)didChangeNetworkReachability:(NSNotification*)notification
{
    NNReachability* reachability = notification.object;
    BOOL available = reachability.isNetworkAvailable;
    TRACE(@"reachability has changed. %@", available ? @"available" : @"not available");
    self.isNetworkAvailable = available;
    if (available && self.state == [NNSocketIOSocketStateDisconnected sharedState] && !self.disconnectionClientInitiated) {
        [self connect];
    }
}
@end

// Abstract state impls =================================================
@implementation NNSocketIOSocketState
- (void)didEnter:(NNSocketIOSocket*)ctx{TRACE();}
- (void)didExit:(NNSocketIOSocket*)ctx{TRACE();}
- (void)didOpen:(NNSocketIOSocket *)ctx{TRACE();}
- (void)didOpenFailed:(NNSocketIOSocket*) ctx error:(NSError*)error{TRACE();}
- (void)didClose:(NNSocketIOSocket*)ctx error:(NSError*)error{TRACE();}
- (void)didReceivePacket:(NNSocketIOSocket *)ctx packet:(NNSocketIOPacket *)packet{}
- (void)connect:(NNSocketIOSocket*)ctx{TRACE();}
- (void)disconnect:(NNSocketIOSocket*)ctx{TRACE();}
- (void)sendPacket:(NNSocketIOSocket*)ctx packet:(NNSocketIOPacket *)packet
{
    TRACE();
    [ctx.sendPacketBuffer addObject:packet];
}
@end
// Concrete state impls =================================================
@implementation NNSocketIOSocketStateDisconnected
SHARED_STATE_METHOD();
- (void)didEnter:(NNSocketIOSocket *)ctx
{
    ctx.disconnectTimeoutDispatch = nil;
}
- (void)connect:(NNSocketIOSocket*)ctx
{
    TRACE();
    [ctx changeState:[NNSocketIOSocketStateConnecting sharedState]];
}
@end
@implementation NNSocketIOSocketStateConnecting
SHARED_STATE_METHOD();
- (void)didEnter:(NNSocketIOSocket*)ctx
{
    TRACE();
    ctx.disconnectionClientInitiated = NO;
    ctx.disconnectionReason = nil;
    [self handshake:ctx];
}
- (void)didOpen:(NNSocketIOSocket *)ctx
{
    TRACE();
    [ctx didOpen];
}
- (void)didOpenFailed:(NNSocketIOSocket *)ctx error:(NSError *)error
{
    TRACE();
    [self fail:ctx error:error];
}
- (void)didReceivePacket:(NNSocketIOSocket *)ctx packet:(NNSocketIOPacket *)packet
{
    TRACE();
    if (packet.endpoint.length > 0) {
        return;
    }
    NSInteger type = packet.messageType;
    if (type == NNSocketIOMessageTypeConnect) {
        [ctx changeState:[NNSocketIOSocketStateConnected sharedState]];
    }  
    [ctx didReceivePacket:packet];
}
- (void)didClose:(NNSocketIOSocket*)ctx error:(NSError*)error
{
    TRACE();
    [self fail:ctx error:error];
}
- (void)handshake:(NNSocketIOSocket*)ctx
{
    TRACE();
    __block NNSocketIOSocket* ctx_ = ctx;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableString* u = nil;
        NSURL* url = nil;
        // Handshake
        u = [NSMutableString string];
        [u appendString:ctx_.secure ? @"https" : @"http"];
        [u appendFormat:@"://"];
        [u appendFormat:@"%@:%d", ctx_.host, ctx_.port];
        [u appendFormat:@"/%@/%d/", ctx_.options.resource, ctx_.options.protocolVersion];
        url = [NSURL URLWithString:u];
        NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:ctx_.options.connectTimeout];
        [req setHTTPMethod:@"POST"];
        [req setHTTPShouldHandleCookies:YES];
        //[req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"content-type"];
        NSHTTPURLResponse* res = nil;
        NSError* error = nil;
        NSData* result = [NSURLConnection sendSynchronousRequest:req returningResponse:&res error:&error];
        if (error) {
            [self fail:ctx error:error];
            return;
        }
        if (res.statusCode != 200) {
            TRACE(@"http status %d", res.statusCode);
            [self failWithCode:ctx_ code:NNSocketIOErrorHandshakeHttpResponseCode];
            return;
        }
        NSString* str = [[[NSString alloc] initWithData:result encoding:NSASCIIStringEncoding] autorelease];
        NSArray* array = [str componentsSeparatedByString:@":"];
        if ([array count] < 3) {
            [self failWithCode:ctx_ code:NNSocketIOErrorHandshakeHttpResponseBody];
            return;
        }
        NSString* sessionId = [array objectAtIndex:0];
        NSString* heartbeatTimeout = [array objectAtIndex:1];
        NSString* closeTimeout = [array objectAtIndex:2];
        if ([sessionId length] == 0) {
            [self failWithCode:ctx_ code:NNSocketIOErrorHandshakeHttpResponseBody];
            return;
        }
        if ([heartbeatTimeout length] == 0) {
            [self failWithCode:ctx_ code:NNSocketIOErrorHandshakeHttpResponseBody];
        }
        if ([closeTimeout length] == 0) {
            [self failWithCode:ctx_ code:NNSocketIOErrorHandshakeHttpResponseBody];
            return;
        }
        NNWebSocket* websocket = [ctx_ createWebSocket:sessionId];
        [websocket connect];
    });
}
- (void)failWithCode:(NNSocketIOSocket*)ctx code:(NNSocketIOErrors)code
{
    TRACE();
    NSError* error = [NSError errorWithDomain:NNSOCKETIO_ERROR_DOMAIN code:code userInfo:nil];
    [self fail:ctx error:error];
}
- (void)fail:(NNSocketIOSocket*)ctx error:(NSError *)error
{
    TRACE();
    [ctx changeState:[NNSocketIOSocketStateDisconnected sharedState]];
    if (ctx.options.retry && ctx.retryAttempts < ctx.options.retryMaxAttempts && ctx.isNetworkAvailable) {
        [self retry:ctx];
    } else {
        [ctx didConnectFailed:error];
    }
}
- (void)retry:(NNSocketIOSocket*)ctx
{
    TRACE();
    __block NNSocketIOSocket* ctx_ = ctx;
    if (ctx.retryAttempts > 0) {
        NSTimeInterval d = ctx_.retryDelay * 2;
        if (d > ctx.options.retryDelayLimit) {
            d = ctx.options.retryDelayLimit;
        }
        ctx_.retryDelay = d;
    }
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * ctx_.retryDelay);
    dispatch_after(delay, dispatch_get_main_queue(), ^{
        if (ctx_.retryAttempts < NSUIntegerMax) {
            ctx_.retryAttempts++;
        }
        [ctx_ connect];
    });
}
@end

@implementation NNSocketIOSocketStateConnected
SHARED_STATE_METHOD();
- (void)didEnter:(NNSocketIOSocket *)ctx
{
    TRACE();
    ctx.retryAttempts = 0;
    ctx.retryDelay = ctx.options.retryDelay;
    [ctx didConnect];
    if (ctx.sendPacketBuffer.count == 0) {
        return;
    }
    for (NNSocketIOPacket* packet in ctx.sendPacketBuffer) {
        [self sendPacket:ctx packet:packet];
    }
    [ctx.sendPacketBuffer removeAllObjects];
}
- (void)didClose:(NNSocketIOSocket*)ctx error:(NSError*)error;{
    TRACE();
    ctx.disconnectionReason = error;
    [ctx changeState:[NNSocketIOSocketStateDisconnected sharedState]];
    [ctx didDisconnect];
}
- (void)didReceivePacket:(NNSocketIOSocket *)ctx packet:(NNSocketIOPacket *)packet
{
    TRACE();
    NSInteger type = packet.messageType;
    BOOL root = packet.endpoint.length == 0;
    if (type == NNSocketIOMessageTypeHeartbeat) {
        NNSocketIOPacket* packet = nil;
        packet = [NNSocketIOPacket packet:NNSocketIOMessageTypeHeartbeat];
        [self sendPacket:ctx packet:packet];
        return;
    } else if (type == NNSocketIOMessageTypeDisconnect && root) {
        [ctx.websocket disconnect];
        [ctx changeState:[NNSocketIOSocketStateDisconnecting sharedState]];
        return;
    }
    [ctx didReceivePacket:packet];
}
- (void)disconnect:(NNSocketIOSocket*)ctx
{
    TRACE();
    NNSocketIOPacket* packet = [NNSocketIOPacket packet:NNSocketIOMessageTypeDisconnect];
    NSString* packetString = [NNSocketIOParser encodePacket:packet];
    NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
    frame.payloadString = packetString;
    [ctx.websocket send:frame];
    ctx.disconnectionClientInitiated = YES;
    [ctx changeState:[NNSocketIOSocketStateDisconnecting sharedState]];
}
- (void)sendPacket:(NNSocketIOSocket *)ctx packet:(NNSocketIOPacket *)packet
{
    TRACE();
    NSString* packetString = [NNSocketIOParser encodePacket:packet];
    NNWebSocketFrame* frame = [NNWebSocketFrame frameText];
    frame.payloadString = packetString;
    [ctx.websocket send:frame];
}
@end

@implementation NNSocketIOSocketStateDisconnecting
SHARED_STATE_METHOD();
- (void)didEnter:(NNSocketIOSocket *)ctx
{
    __block NNSocketIOSocketStateDisconnecting* self_ = self;
    __block NNSocketIOSocket* ctx_ = ctx;
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * ctx.options.disconnectTimeout);
    ctx.disconnectTimeoutDispatch = [NNDispatch dispatchAfter:delay queue:dispatch_get_main_queue() block:^{
        TRACE();
        NSError* error = [NSError errorWithDomain:NNSOCKETIO_ERROR_DOMAIN code:NNSocketIOErrorDisconnectTimeout userInfo:nil];
        [self_ didClose:ctx_ error:error];
    }];

}
- (void)didReceivePacket:(NNSocketIOSocket *)ctx packet:(NNSocketIOPacket *)packet
{
    TRACE();
    NSInteger type = packet.messageType;
    BOOL root = packet.endpoint.length == 0;
    if (type == NNSocketIOMessageTypeHeartbeat) {
        return;
    } else if (type == NNSocketIOMessageTypeDisconnect && root) {
        [ctx.websocket disconnect];
        return;
    }
    [ctx didReceivePacket:packet];
}
- (void)didClose:(NNSocketIOSocket*)ctx error:(NSError*)error;{
    TRACE();
    ctx.disconnectionReason = error;
    [ctx changeState:[NNSocketIOSocketStateDisconnected sharedState]];
    [ctx didDisconnect];
}
- (void)didExit:(NNSocketIOSocket*)ctx
{
    [ctx.disconnectTimeoutDispatch cancel];
}

@end
