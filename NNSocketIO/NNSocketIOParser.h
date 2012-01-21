#import <Foundation/Foundation.h>
#import "NNSocketIOPacket.h"

@interface NNSocketIOParser : NSObject
+ (NNSocketIOPacket*)decodePacket:(NSString*)string;
+ (NSString*)encodePacket:(NNSocketIOPacket*)packet;
@end
