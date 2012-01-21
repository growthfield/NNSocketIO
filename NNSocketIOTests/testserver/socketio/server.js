var fs = require('fs');
var io = require('socket.io').listen(8080);
var authio = require('socket.io').listen(8081);
var sslio = require('socket.io').listen(8443, {
    key: fs.readFileSync('key.pem'),
    cert: fs.readFileSync('cert.pem')
});
var parseCookie = require('connect').utils.parseCookie;

var echo_message = io.of('/echo_message');
echo_message.on('connection', function (socket) {
    socket.on('message', function(msg) {
        socket.send(msg);
    });
    socket.on('disconnect', function() {
    });
});

var client_ack_message = io.of('/client_ack_message');
client_ack_message.on('connection', function (socket) {
    socket.on('message', function(msg) {
        socket.send('got message', function() {
            socket.send('got ack');
        });
    });
});

var echo_json = io.of('/echo_json');
echo_json.on('connection', function (socket) {
    socket.on('message', function(msg) {
        socket.json.send(msg);
    });
});

var echo_event = io.of('/event');
echo_event.on('connection', function(socket) {
    socket.on('profile', function(profile) {
        socket.emit('welcome', {hello: profile.name});
    });
    socket.on('profile_ack', function(profile, fn) {
        fn({hello: profile.name});
    });
    socket.on('tweet', function(word0, word1) {
        socket.emit('tweet_echo', 'You said', word1);
    });
    socket.on('tweet_ack', function(word0, word1, fn) {
        fn('You said', word1);
    });
});

var client_ack_event = io.of('/client_ack_event');
client_ack_event.on('connection', function(socket) {
    socket.emit('tell me your name', function(yourname) {
        socket.emit('i know your name', {name: yourname});
    });
});

var client_force_disconnect = io.of('/client_force_disconnect');
client_force_disconnect.on('connection', function(socket) {
    socket.on('bye', function() {
        console.log('byebye');
        socket.disconnect();
    });
});

var auth_error = io.of('/auth_error').authorization(function(handshakeData, callback) {
    callback(null, false);
});

authio.configure(function (){
    authio.set('authorization', function (handshakeData, callback) {
        var auth = false;
        if(handshakeData.headers.cookie) {
            var v = parseCookie(handshakeData.headers.cookie)['testauth'];
            auth = v === '1';
        }
        callback(null, auth);
    });
});
