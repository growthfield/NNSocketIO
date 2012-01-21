#import "NNSocketIONamespace.h"
#import "NNSocketIOSocket.h"
#import "NNSocketIO.h"
#import "NNSocketIODebug.h"

@interface NNSocketIONamespace()
@property(nonatomic, assign) NNSocketIOSocket* socket;
@property(nonatomic, retain) NSString* name;
@property(nonatomic, assign) NSUInteger ackCount;
@property(nonatomic, retain) NSMutableDictionary* ackListeners;
- (void)sendWithMessageType:(NNSocketIOMessageType)type msg:(NSString*)msg listener:(NNSocketIOAckListener)listener;
@end

@implementation NNSocketIONamespace
@synthesize socket = socket_;
@synthesize name = name_;
@synthesize ackCount = ackCount_;
@synthesize ackListeners = ackListeners_;
@synthesize json = json_;
+ (NNSocketIONamespace*)namespaceWithSocket:(NNSocketIOSocket*)socket name:(NSString*)name
{
    TRACE();
    return [[[self alloc] initWithSocket:socket name:name] autorelease];
}
- (id)initWithSocket:(NNSocketIOSocket *)socket name:(NSString *)name
{
    TRACE();
    self = [super init];
    if (self) {
        self.socket = socket;
        self.name = name;
        self.ackCount = 0;
        self.ackListeners = [NSMutableDictionary dictionary];
        self.json = [NNSocketIONamespaceJsonFace faceWithNamespace:self];
    }
    return self;
}
- (void)dealloc
{
    TRACE();
    self.socket = nil;
    self.name = nil;
    self.ackListeners = nil;
    [super dealloc];
}
- (id<NNSocketIOClient>)of:(NSString*)name
{
    TRACE();
    return [self.socket of:name];
}
- (void)packet:(NNSocketIOPacket *)packet
{
    TRACE();
    packet.endpoint = self.name;
    [self.socket sendPacket:packet];
}
- (void)onPacket:(NNSocketIOPacket *)packet
{
    TRACE();
    NSUInteger type = packet.messageType;
    if (type == NNSocketIOMessageTypeConnect) {
        [self $emit:@"connect"];
    } else if (NNSocketIOMessageTypeMessage == type || NNSocketIOMessageTypeJSONMessage == type) {
        if (packet.messageId) {
            NNSocketIOPacket* p = [NNSocketIOPacket packet:NNSocketIOMessageTypeAck];
            p.ackMessageId = packet.messageId;
            [self packet:p];
        }
        [self $emit:@"message" args:[[NNArgs args] add:packet.data]];
    } else if (type == NNSocketIOMessageTypeEvent) {
        NNArgs* args = [[NNArgs args] addAll:packet.args];
        if (packet.explicitAck) {
            __block NNSocketIONamespace* self_ = self;
            NNSocketIOAck ack =^(NNArgs* args){
                NNSocketIOPacket* p = [NNSocketIOPacket packet:NNSocketIOMessageTypeAck];
                p.ackMessageId = packet.messageId;
                p.args = args.array;
                [self_ packet:p];
            };
            [args add:[[ack copy] autorelease]];
        }
        [self $emit:packet.name args:args];
    } else if (type == NNSocketIOMessageTypeAck) {
        NSNumber* ackId = packet.ackMessageId;
        id listener = [self.ackListeners objectForKey:ackId];
        if (listener) {
            ((NNSocketIOAckListener)listener)([[NNArgs args] addAll:packet.args]);
            [self.ackListeners removeObjectForKey:ackId];
        }
    } else if (type == NNSocketIOMessageTypeError) {
        NSMutableDictionary* info = [NSMutableDictionary dictionary];
        NSString* reason = packet.reason;
        NSString* advice = packet.advice;
        if (reason) {
            [info setObject:reason forKey:@"reason"];
        }
        if (advice) {
            [info setObject:advice forKey:@"advice"];            
        }
        NSError* error = [NSError errorWithDomain:NNSOCKETIO_ERROR_DOMAIN code:NNSocketIOErrorErrorPacket userInfo:info];
        NNArgs* args = [[NNArgs args] add:error];
        if ([NNSOCKETIO_ERROR_REASON_UNAUTHORIZED isEqualToString:reason]) {
            [self $emit:@"connect_failed" args:args];
        } else {
            [self $emit:@"error" args:args];            
        }
    }
}
- (void)send:(id)msg
{
    TRACE();
    [self send:msg listener:nil];
}
-(void)send:(id)msg listener:(NNSocketIOAckListener)listener
{
    TRACE();
    [self sendWithMessageType:NNSocketIOMessageTypeMessage msg:msg listener:listener];
}
- (void)sendWithMessageType:(NNSocketIOMessageType)type msg:(id)msg listener:(NNSocketIOAckListener)listener
{
    TRACE();
    NNSocketIOPacket* packet = [NNSocketIOPacket packet:type];
    packet.data = msg;
    if (listener) {
        NSNumber* msgId = [NSNumber numberWithUnsignedInteger:++self.ackCount];
        packet.messageId = msgId;
        [self.ackListeners setObject:[[listener copy] autorelease] forKey:msgId];
    }
    [self packet:packet];
}
- (void)emit:(NSString*)eventName;
{
    TRACE();
    [self emit:eventName listener:nil];
}
- (void)emit:(NSString*)eventName listener:(NNSocketIOAckListener)listener
{
    TRACE();
    [self emit:eventName args:nil listener:listener];
}
- (void)emit:(NSString*)eventName args:(NNArgs*)args
{
    TRACE();
    [self emit:eventName args:args listener:nil];
}
- (void)emit:(NSString*)eventName args:(NNArgs*)args listener:(NNSocketIOAckListener)listener
{
    TRACE();
    NNSocketIOPacket* packet = [NNSocketIOPacket packet:NNSocketIOMessageTypeEvent];
    packet.name = eventName;
    if (args) {
        packet.args = [args array];
    }
    if (listener) {
        NSNumber* msgId = [NSNumber numberWithUnsignedInteger:++self.ackCount];
        packet.messageId = msgId;
        packet.explicitAck = YES;
        [self.ackListeners setObject:[[listener copy] autorelease] forKey:msgId];
    }
    [self packet:packet];

}
- (void)$emit:(NSString*)eventName;
{
    TRACE();
    [super emit:eventName args:nil];
}
- (void)$emit:(NSString*)eventName args:(NNArgs*)args
{
    TRACE();
    [super emit:eventName args:args];
}
- (void)disconnect
{
    TRACE();
    if ([self.name length] == 0) {
        [self.socket disconnect];
    } else {
        [self packet:[NNSocketIOPacket packet:NNSocketIOMessageTypeDisconnect]];
        [self $emit:@"disconnect"];
    }
}
@end

@interface NNSocketIONamespaceJsonFace()
@property(nonatomic, assign) NNSocketIONamespace* namespace;
@end

@implementation NNSocketIONamespaceJsonFace
@synthesize namespace = namespace_;
+ (NNSocketIONamespaceJsonFace*)faceWithNamespace:(NNSocketIONamespace *)nsp
{
    TRACE();
    return [[[NNSocketIONamespaceJsonFace alloc] initWithNamespace:nsp] autorelease];
}
- (id)initWithNamespace:(NNSocketIONamespace *)nsp
{
    TRACE();
    self = [super init];
    if (self) {
        self.namespace = nsp;
    }
    return self;
}
- (void)send:(id)json
{
    TRACE();
    [self send:json listener:nil];
}
- (void)send:(id)json listener:(NNSocketIOAckListener)listener
{
    TRACE();
    [self.namespace sendWithMessageType:NNSocketIOMessageTypeJSONMessage msg:json listener:listener];
}
- (void)emit:(NSString*)eventName;
{
    TRACE();
    [self.namespace emit:eventName];
}
- (void)emit:(NSString*)eventName listener:(NNSocketIOAckListener)listener
{
    TRACE();
    [self.namespace emit:eventName listener:listener];
}
- (void)emit:(NSString*)eventName args:(NNArgs*)args
{
    TRACE();
    [self.namespace emit:eventName args:args];
}
- (void)emit:(NSString*)eventName args:(NNArgs*)args listener:(NNSocketIOAckListener)listener
{
    TRACE();
    [self.namespace emit:eventName args:args listener:listener];
}
@end
