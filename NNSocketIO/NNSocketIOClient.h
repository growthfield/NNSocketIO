#import <Foundation/Foundation.h>
#import "NNEventEmitter.h"

typedef void (^NNSocketIOAck)(NNArgs* ack);
typedef void (^NNSocketIOAckListener)(NNArgs* ack);

@protocol NNSocketIOMessaging <NSObject>
- (void)send:(id)msg;
- (void)send:(id)msg listener:(NNSocketIOAckListener)listener;
@end

@protocol NNSocketIOEmitting <NSObject>
- (void)emit:(NSString*)eventName;
- (void)emit:(NSString*)eventName listener:(NNSocketIOAckListener)listener;
- (void)emit:(NSString*)eventName args:(NNArgs*)event;
- (void)emit:(NSString*)eventName args:(NNArgs*)args listener:(NNSocketIOAckListener)listener;
@end

@protocol NNSocketIOSending <NNSocketIOMessaging, NNSocketIOEmitting>
@end

@protocol NNSocketIOClient <NNSocketIOSending>
@property(nonatomic, assign) id<NNSocketIOSending> json;
- (id<NNSocketIOClient>)of:(NSString*)name;
- (void)disconnect;
- (void)on:(NSString*)eventName listener:(NNEventListener)listener;
- (void)once:(NSString*)eventName listener:(NNEventListener)listener;
- (NSArray*)listeners:eventName;
- (void)removeLisitener:(NSString*)eventName listener:(NNEventListener)listener;
@end
