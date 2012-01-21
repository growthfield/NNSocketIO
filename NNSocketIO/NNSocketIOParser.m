#import "NNSocketIOParser.h"
#import "JSONKit.h"
#import "NNSocketIODebug.h"

@interface NNSocketIOParser()
+ (NNSocketIOPacket*)decodePacket:(NSString*) string;
@end

@implementation NNSocketIOParser
+ (NNSocketIOPacket*)decodePacket:(NSString *)string
{
    TRACE();
    static NSRegularExpression *msgRegexp = nil;
    static NSRegularExpression *ackDataRegexp = nil;    
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSError* error = nil;
        msgRegexp = [[NSRegularExpression alloc] initWithPattern:@"([^:]+):([0-9]+)?(\\+)?:([^:]+)?:?([\\s\\S]*)?" options:0 error:&error];
        ackDataRegexp = [[NSRegularExpression alloc] initWithPattern:@"^([0-9]+)(\\+)?(.*)" options:0 error:&error];
    });
    NSString* type = nil;
    NSString* mid = nil;
    NSString* ack = nil;
    NSString* endpoint = nil;
    NSString* data = nil;
    NSTextCheckingResult* msgMatch = [msgRegexp firstMatchInString:string options:0 range:NSMakeRange(0, [string length])];
    if (msgMatch) {
        NSRange range = [msgMatch rangeAtIndex:1];
        if (range.location != NSNotFound) {
            type = [string substringWithRange:range];
        }
        range = [msgMatch rangeAtIndex:2];
        if (range.location != NSNotFound) {
            mid = [string substringWithRange:range];
        }
        range = [msgMatch rangeAtIndex:3];
        if (range.location != NSNotFound) {
            ack = [string substringWithRange:range];
        }
        range = [msgMatch rangeAtIndex:4];
        if (range.location != NSNotFound) {
            endpoint = [string substringWithRange:range];
        }
        range = [msgMatch rangeAtIndex:5];
        if (range.location != NSNotFound) {
            data = [string substringWithRange:range];
        }
    }
    NSUInteger messageType = [type integerValue];
    NNSocketIOPacket* packet = [NNSocketIOPacket packet:messageType];
    if ([mid length] > 0) {
        packet.messageId = [NSNumber numberWithInteger:[mid integerValue]];
    }
    packet.endpoint = endpoint ? endpoint : @"";
    packet.explicitAck = ack.length > 0;
    if (messageType == NNSocketIOMessageTypeAck) {
        if (data) {
            NSTextCheckingResult* ackDataMatch = [ackDataRegexp firstMatchInString:data options:0 range:NSMakeRange(0, [data length])];
            if (ackDataMatch) {
                NSString* ackId = [data substringWithRange:[ackDataMatch rangeAtIndex:1]];
                packet.ackMessageId = [NSNumber numberWithUnsignedInteger:[ackId integerValue]];
                NSString* ackData = [data substringWithRange:[ackDataMatch rangeAtIndex:3]];
                if (ackData) {
                    packet.args = [ackData objectFromJSONString];
                }
            }
        }        
    } else if (messageType == NNSocketIOMessageTypeMessage) {
        if (data && data.length > 0) {
            packet.data = data;
        }
    } else if (messageType == NNSocketIOMessageTypeJSONMessage) {
        packet.data = [data objectFromJSONString];
    } else if (messageType == NNSocketIOMessageTypeEvent) {
        NSDictionary* json = [data objectFromJSONString];
        packet.name = [json objectForKey:@"name"];
        packet.args = [json objectForKey:@"args"];
    } else if (messageType == NNSocketIOMessageTypeError) {
        NSArray* pieces = [data componentsSeparatedByString:@"+"];
        NSUInteger cnt = pieces.count;
        if (cnt > 0) {
            packet.reason = [pieces objectAtIndex:0];
        }
        if (cnt > 1) {
            packet.advice = [pieces objectAtIndex:1];
        }
    }
    return packet;
}

+ (NSString*)encodePacket:(NNSocketIOPacket*)packet
{
    TRACE();
    NSString* data = nil;
    NSUInteger type = packet.messageType;
    if (type == NNSocketIOMessageTypeMessage) {
        data = packet.data;        
    } else if (type == NNSocketIOMessageTypeJSONMessage) {
        data = [packet.data JSONString];
    } else if (type == NNSocketIOMessageTypeAck) {
        NSMutableString* ackData = [NSMutableString string];
        [ackData appendString:[packet.ackMessageId stringValue]];
        NSArray* args = packet.args;
        if (args && args.count > 0) {
            [ackData appendString:@"+"];
            [ackData appendString:[args JSONString]];
        }
        data = ackData;
    } else if (type == NNSocketIOMessageTypeEvent) {
        NSMutableDictionary* json = [NSMutableDictionary dictionaryWithObjectsAndKeys:packet.name, @"name", nil];
        NSArray* args = packet.args;
        if (args) {
            [json setObject:args forKey:@"args"];
        }
        data = [json JSONString];
    } else if (type == NNSocketIOMessageTypeError) {
        NSMutableString* errData = [NSMutableString string];
        if (packet.reason) {
            [errData appendString:packet.reason];
        }
        if (packet.advice) {
            [errData appendString:@"+"];
            [errData appendString:packet.advice];            
        }
    }
    NSMutableArray* array = [NSMutableArray array];
    [array addObject:[NSNumber numberWithInteger:packet.messageType]];
    NSMutableString* msgId = [NSMutableString string];
    if (packet.messageId) {
        [msgId appendString:[packet.messageId stringValue]];
    }
    if (packet.explicitAck) {
        [msgId appendString:@"+"];
    }
    
    [array addObject:msgId];
    [array addObject:packet.endpoint];
    if (data) {
        [array addObject:data];
    }
    return [array componentsJoinedByString:@":"];
}
@end
