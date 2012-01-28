#import <Foundation/Foundation.h>
#import "NNEventEmitter.h"
#import "NNSocketIOOptions.h"
#import "NNSocketIONamespace.h"
#import "NNSocketIOPacket.h"
#import "NNWebSocket.h"
#import "NNDispatch.h"

@class NNSocketIOSocketState;

@interface NNSocketIOSocket : NNEventEmitter
{
@private
    NNSocketIOOptions* options_;
    BOOL secure_;
    NSString* host_;
    NSInteger port_;
    NNSocketIOSocketState* state_;
    NSString* sessionId_;
    NSMutableDictionary* namespaces_;
    NSTimeInterval retryDelay_;
    NSUInteger retryAttempts_;
    NSUInteger connectionRecoveryAttempts_;
    NSMutableArray* sendPacketBuffer_;
    NNWebSocket* websocket_;
    BOOL disconnectionClientInitiated_;
    NSError* disconnectionReason_;
    NNDispatch* disconnectTimeoutDispatch_;
    BOOL isNetworkAvailable_;
}
@property(nonatomic, retain) NNSocketIOOptions* options;
@property(nonatomic, assign) BOOL secure;
@property(nonatomic, retain) NSString* host;
@property(nonatomic, assign) NSInteger port;
@property(nonatomic, retain) NSString* sessionId;
- (id)initWithURL:(NSURL*)url options:(NNSocketIOOptions*)options;
- (NNSocketIONamespace*)of:(NSString*)name;
- (void)sendPacket:(NNSocketIOPacket*)packet;
- (void)disconnect;
@end
