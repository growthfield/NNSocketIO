#import "NNSocketIO.h"
#import "NNSocketIOSocket.h"
#import "NNSocketIODebug.h"

static NSString* UniqueURI(NSURL* url)
{
    NSMutableString* uri = [NSMutableString string];
    NSString* scheme = url.scheme;
    NSNumber* p = url.port;
    NSUInteger port;
    if (p) {
        port = [p unsignedIntegerValue];
    } else {
        if ([@"https" isEqualToString:scheme]) {
            port = 443;
        } else {
            port = 80;
        }
    }
    [uri appendFormat:@"%@://%@:%d", scheme, url.host, port];
    return uri;
}

@interface NNSocketIO()
@property(nonatomic, retain) NSMutableDictionary* sockets;
@end

@implementation NNSocketIO
@synthesize sockets = sockets_;
+ (NNSocketIO*)io
{
    TRACE();
    return [[[self alloc] init] autorelease];
}
- (id)init
{
    TRACE();
    self = [super init];
    if (self) {
        self.sockets = [NSMutableDictionary dictionary];
    }
    return self;
}
- (void)dealloc
{
    TRACE();
    self.sockets = nil;
}
- (id<NNSocketIOClient>)connect:(NSURL*)url
{
    TRACE();
    return [self connect:url options:nil];
}
- (id<NNSocketIOClient>)connect:(NSURL*)url options:(NNSocketIOOptions*)options;
{
    TRACE();
    NNSocketIOOptions* opts = nil;
    if (options) {
        opts = [[options copy] autorelease];
    } else {
        opts = [NNSocketIOOptions options];
    }
    NSString* uniqueUri = UniqueURI(url);
    NNSocketIOSocket* socket = nil;
    socket = [self.sockets objectForKey:uniqueUri];
    if (!socket) {
        LOG(@"NNSocketIO Socket craeted. %@", uniqueUri);
        socket = [[[NNSocketIOSocket alloc] initWithURL:url options:opts] autorelease];
        [self.sockets setObject:socket forKey:uniqueUri];
    }        
    NSString* name = url.path;
    return [socket of:name];
}
@end
