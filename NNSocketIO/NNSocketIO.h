#import "NNSocketIOOptions.h"
#import "NNSocketIOClient.h"

#define NNSOCKETIO_ERROR_DOMAIN @"NNSocketIOErrorDmain"

typedef enum {
    NNSocketIOErrorHandshakeHttpResponseCode = 100,
    NNSocketIOErrorHandshakeHttpResponseBody,
    NNSocketIOErrorUnexpectedDisconnection,
    NNSocketIOErrorErrorPacket
} NNSocketIOErrors;

@interface NNSocketIO : NSObject
{
    @private
    NSMutableDictionary* sockets_;
}
+ (NNSocketIO*)io;
- (id<NNSocketIOClient>)connect:(NSURL*)url;
- (id<NNSocketIOClient>)connect:(NSURL*)url options:(NNSocketIOOptions*)options;
@end
