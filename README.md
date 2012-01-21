# NNSocketIO

NNSocketIO is socket.io client clone for iOS.  
Currently, This library is not tested enough and it only be tested on iPhone simulator with socket.io 0.8.7

## Usage example

```objective-c
NSURL* url = [NSURL URLWithString:@"http://localhost:8080"];
NNSocketIO* io = [NNSocketIO io];
__block id<NNSocketIOClient> client = [io connect:url];
[client on:@"connect" listener:^(NNArgs* args) {
    NSLog(@"Connected");
    [client send:@"Hello world!"];
}];
[client on:@"message" listener:^(NNArgs* args) {
    NSString* msg = [args get:0];
    NSLog(@"Message received! %@", msg);
}];
[client on:@"disconnect" listener:^(NNArgs* args) {
    NSLog(@"Bye!");
}];
```

NNSocketIO instance is equivalent to a socket.io's io object, so that it must be retained and it should be shared on an App.

Event listener is expressed as a block like a javascript's callback function and it must have just one argument typed NNArgs which is substitute for a javascript's variable argument.

### Sending and receiving a simple message

```objective-c
[client on:@"connect" listener:^(NNArgs* args) {
    [client send:@"Hello world!"];
}];
[client on:@"message" listener:^(NNArgs* args) {
    NSString* msg = [args get:0];
}];
```
### Sending and receiving a json message

```objective-c
[client on:@"connect" listener:^(NNArgs* args) {
    NSDictionary* msg  = [NSDictionary dictionaryWithObjectsAndKeys:@"foo", @"firstname", @"bar", @"lastname",nil];
    [client.json send:msg];
}];
[client on:@"message" listener:^(NNArgs* args) {
    NSDictionary* msg = [args get:0];
}];
```
NNSocketIO uses JSONKit to serialize/deserialize JSON data.

### Getting an acknowledgment after sending a simple/json message

Sending a message with an acknowledgement listener, listener will be invoked after server receives its message.

```objective-c
[client send:msg listener:^(NNArgs* args){
    NSLog(@"Got an acknowledgment!");
}];
```

A simple/json message can get an implicit acknowledgement returned by socket.io server automatically.  
callback args would be always nil in the case of implicit acknowledgement.

### Emitting and receiving an envet

```objective-c
[client on:@"connect" listener:^(NNArgs* args) {
    NSDictionary* profile = [NSDictionary dictionaryWithObjectsAndKeys:@"taro", @"name", [NSNumber numberWithInt:20], @"age",nil];
    NNArgs* args = [[NNArgs args] add:profile];
    [client emit:@"profile" args:args];
}];
[client on:@"profile" listener:^(NNArgs* args) {
    NSDictionary* profile = [args get:0];
}];
```

### Getting an acknowledgment after emitting an event

Emitting an event with an acknowledgement listener, listener will be invoked after server app acknowledges its event.

```objective-c
NSDictionary* profile = [NSDictionary dictionaryWithObjectsAndKeys:@"taro", @"name", [NSNumber numberWithInt:20], @"age",nil];
NNArgs* args = [[NNArgs args] add:profile];
[client emit:@"profile" args:args listener:^(NNArgs* args) {
    NSLog(@"Got an acknowledgment!");
    NSDictionary* result = [args get:0];
}];
```
Emitting an event can get an explicit acknowledgement returned by socket.io server app.  
value of explicit acknowledgement args depends on server app.

### Namespacing a socket

A client can be created on each namespace and namespace on same scheme, host and port shares one websocket connection.

```objective-c
NSURL* url = [NSURL URLWithString:@"http://localhost:8080"];
NSURL* newsurl = [NSURL URLWithString:@"http://localhost:8080/news"];
NSURL* echourl = [NSURL URLWithString:@"http://localhost:8080/echo"];
NNSocketIO* io = [NNSocketIO io];
__block id<NNSocketIOClient> root = [io connect:url];
__block id<NNSocketIOClient> news = [io connect:newsurl];
__block id<NNSocketIOClient> echo = [io connect:echourl];
```
also

```objective-c
NSURL* url = [NSURL URLWithString:@"http://localhost:8080"];
NNSocketIO* io = [NNSocketIO io];
__block id<NNSocketIOClient> root = [io connect:url];
__block id<NNSocketIOClient> news = [root of:@"/news"];
__block id<NNSocketIOClient> echo = [root of:@"/echo"];
```

