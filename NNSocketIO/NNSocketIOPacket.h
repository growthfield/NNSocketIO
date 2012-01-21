#define NNSOCKETIO_ERROR_REASON_UNAUTHORIZED @"2"

typedef enum {
    NNSocketIOMessageTypeDisconnect = 0,
    NNSocketIOMessageTypeConnect,
    NNSocketIOMessageTypeHeartbeat,
    NNSocketIOMessageTypeMessage,
    NNSocketIOMessageTypeJSONMessage,
    NNSocketIOMessageTypeEvent,
    NNSocketIOMessageTypeAck,
    NNSocketIOMessageTypeError,
    NNSocketIOMessageTypeNoop
} NNSocketIOMessageType;

@interface NNSocketIOPacket : NSObject
{
@private
    NSUInteger messageType_;
    NSNumber* messageId_;
    NSNumber* ackMessageId_;
    BOOL explicitAck_;
    NSString* endpoint_;
    NSString* reason_;
    NSString* advice_;
    id data_;
    NSString* name_;
    NSArray* args_;
}
@property(nonatomic, readonly, assign) NSUInteger messageType;
@property(nonatomic, retain) NSNumber* messageId;
@property(nonatomic, retain) NSNumber* ackMessageId;
@property(nonatomic, assign) BOOL explicitAck;
@property(nonatomic, retain) NSString* endpoint;
@property(nonatomic, retain) NSString* reason;
@property(nonatomic, retain) NSString* advice;
@property(nonatomic, retain) id data;
@property(nonatomic, retain) NSString* name;
@property(nonatomic, retain) NSArray* args;
+ (NNSocketIOPacket*)packet:(NNSocketIOMessageType)messageType;
- (id)initWithMessageType:(NNSocketIOMessageType)messageType;
@end
