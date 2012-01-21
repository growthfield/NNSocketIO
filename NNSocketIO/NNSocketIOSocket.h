#import <Foundation/Foundation.h>
#import "NNEventEmitter.h"
#import "NNSocketIOOptions.h"
#import "NNSocketIONamespace.h"
#import "NNSocketIOPacket.h"
#import "NNWebSocket.h"

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
    NSMutableArray* sendPacketBuffer;
    NNWebSocket* websocket_;
    NSTimer* retryTimer_;
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
- (void)didConnect;
- (void)didConnectFailed:(NSError*)error;
- (void)didDisconnect:(BOOL)clientInitiated error:(NSError*)error;
- (void)didOpen;
- (void)didClose:(NSError*)error;
- (void)didReceivePacket:(NNSocketIOPacket*)packet;
@end
