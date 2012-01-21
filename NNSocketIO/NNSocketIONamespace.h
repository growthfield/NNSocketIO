#import <Foundation/Foundation.h>
#import "NNEventEmitter.h"
#import "NNSocketIOPacket.h"
#import "NNSocketIOClient.h"

@class NNSocketIOSocket;

@interface NNSocketIONamespace : NNEventEmitter<NNSocketIOClient>
{
    @private
    NNSocketIOSocket* socket_;
    NSString* name_;
    NSUInteger ackCount_;
    NSMutableDictionary* ackListeners_;
    id<NNSocketIOSending> json_;
}
+ (NNSocketIONamespace*)namespaceWithSocket:(NNSocketIOSocket*)socket name:(NSString*)name;
- (id)initWithSocket:(NNSocketIOSocket*)socket name:(NSString*)name;
- (void)packet:(NNSocketIOPacket*)packet;
- (void)onPacket:(NNSocketIOPacket*)packet;
- (void)$emit:(NSString*)eventName;
- (void)$emit:(NSString*)eventName args:(NNArgs*)event;
- (void)disconnect;
@end

@interface NNSocketIONamespaceJsonFace : NSObject<NNSocketIOSending>
{
@private
    NNSocketIONamespace* namespace_;
}
+ (id)faceWithNamespace:(NNSocketIONamespace*)nsp;
- (id)initWithNamespace:(NNSocketIONamespace*)nsp;
@end
