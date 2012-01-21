#import "NNSocketIOOptions.h"
#import "NNSocketIODebug.h"

@implementation NNSocketIOOptions

@synthesize resource = resource_;
@synthesize protocolVersion = protocolVersion_;
@synthesize connectTimeout = connectTimeout_;
@synthesize retry = retry_;
@synthesize retryDelay = retryDelay_;
@synthesize retryDelayLimit = retryDelayLimit_;
@synthesize retryMaxAttempts = retryMaxAttempts_;
@synthesize connectionRecovery = connectionRecovery_;
@synthesize connectionRecoveryAttempts = connectionRecoveryAttempts_;
@synthesize tlsSettings = tlsSettings_;
+ (id)options
{
    TRACE();
    return [[[self alloc] init] autorelease];
}
- (id)init
{
    TRACE();
    self = [super init];
    if (self) {
        self.resource = @"socket.io";
        self.protocolVersion = 1;
        self.connectTimeout = 10;
        self.retry = YES;
        self.retryDelay = 3;
        self.retryDelayLimit = 60 * 30;
        self.retryMaxAttempts = -1;
        self.connectionRecovery = YES;
        self.connectionRecoveryAttempts = NSUIntegerMax;
    }
    return self;
}
- (void)dealloc
{
    TRACE();
    self.resource = nil;
    self.tlsSettings = nil;
    [super dealloc];
}
- (id)copyWithZone:(NSZone *)zone
{
    TRACE();
    NNSocketIOOptions* o = [[NNSocketIOOptions allocWithZone:zone] init];
    if (o) {
        o.resource = [[self.resource copyWithZone:zone] autorelease];
        o.protocolVersion = self.protocolVersion;
        o.connectTimeout = self.connectTimeout;
        o.retry = self.retry;
        o.retryDelay = self.retryDelay;
        o.retryDelayLimit = self.retryDelayLimit;
        o.retryMaxAttempts = self.retryMaxAttempts;
        o.connectionRecovery = self.connectionRecovery;
        o.connectionRecoveryAttempts = self.connectionRecoveryAttempts;
        o.tlsSettings = [[self.tlsSettings copyWithZone:zone] autorelease];
    }
    return o;
}
@end
