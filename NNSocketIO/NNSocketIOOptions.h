#import <Foundation/Foundation.h>

@interface NNSocketIOOptions : NSObject<NSCopying>
{
@private
    NSString* resource_;
    NSUInteger protocolVersion_;
    NSTimeInterval connectTimeout_;
    BOOL retry_;
    NSTimeInterval retryDelay_;
    NSTimeInterval retryDelayLimit_;
    NSUInteger retryAttempts_;
    NSUInteger retryMaxAttempts_;
    BOOL connectionRecovery;
    NSUInteger connectionRecoveryAttempts_;
    NSDictionary* tlsSettings_;
    BOOL enableBackgroundingOnSocket_;
    NSTimeInterval disconnectTimeout_;
    NSString* origin_;
}
@property(nonatomic, retain) NSString* resource;
@property(nonatomic, assign) NSUInteger protocolVersion;
@property(nonatomic, assign) NSTimeInterval connectTimeout;
@property(nonatomic, assign) BOOL retry;
@property(nonatomic, assign) NSTimeInterval retryDelay;
@property(nonatomic, assign) NSTimeInterval retryDelayLimit;
@property(nonatomic, assign) NSUInteger retryMaxAttempts;
@property(nonatomic, assign) BOOL connectionRecovery;
@property(nonatomic, assign) NSUInteger connectionRecoveryAttempts;
@property(nonatomic, retain) NSDictionary* tlsSettings;
@property(nonatomic, assign) BOOL enableBackgroundingOnSocket;
@property(nonatomic, assign) NSTimeInterval disconnectTimeout;
@property(nonatomic, retain) NSString* origin;
+ (id)options;
@end
