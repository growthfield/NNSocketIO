#import "NNSocketIOPacket.h"
#import "NNSocketIODebug.h"

@implementation NNSocketIOPacket
@synthesize messageType = messageType_;
@synthesize messageId = messageId_;
@synthesize ackMessageId = ackMessageId_;
@synthesize explicitAck = explicitAck_;
@synthesize endpoint = endpoint_;
@synthesize reason = reason_;
@synthesize advice = advice_;
@synthesize data = data_;
@synthesize name = name_;
@synthesize args = args_;
+ (NNSocketIOPacket*)packet:(NNSocketIOMessageType)messageType
{
    TRACE();
    return [[[self alloc] initWithMessageType:messageType] autorelease];
}
- (id)initWithMessageType:(NNSocketIOMessageType)messageType
{
    TRACE();
    self = [super init];
    if (self) {
        messageType_ = messageType;
        self.endpoint = @"";
        self.explicitAck = NO;
    }
    return self;    
}
- (void)dealloc
{
    TRACE();
    self.messageId = nil;
    self.ackMessageId = nil;
    self.endpoint = nil;
    self.reason = nil;
    self.advice = nil;
    self.data = nil;
    self.name = nil;
    self.args = nil;
    [super dealloc];
}
@end
