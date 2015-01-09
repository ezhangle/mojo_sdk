// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of bindings;

abstract class Interface {
  core.MojoMessagePipeEndpoint _endpoint;
  core.MojoEventStream _eventStream;
  List _sendQueue;
  bool _isOpen;

  Future<Message> handleMessage(MessageReader reader);

  Interface(core.MojoMessagePipeEndpoint endpoint) :
      _endpoint = endpoint,
      _sendQueue = [],
      _eventStream = new core.MojoEventStream(endpoint.handle),
      _isOpen = false;

  Interface.fromHandle(int handle) {
    _endpoint =
        new core.MojoMessagePipeEndpoint(new core.MojoHandle(handle));
    _sendQueue = [];
    _eventStream = new core.MojoEventStream(_endpoint.handle);
    _isOpen = false;
  }

  void _doRead() {
    assert(_eventStream.readyRead);

    // Query how many bytes are available.
    var result = _endpoint.query();
    assert(result.status.isOk || result.status.isResourceExhausted);

    // Read the data and view as a message.
    var bytes = new ByteData(result.bytesRead);
    var handles = new List<core.MojoHandle>(result.handlesRead);
    result = _endpoint.read(bytes, result.bytesRead, handles);
    assert(result.status.isOk || result.status.isResourceExhausted);
    var message = new Message(bytes, handles);
    var reader = new MessageReader(message);

    // Prepare the response.
    var responseFuture = handleMessage(reader);

    // If there's a response, queue it up for sending.
    if (responseFuture != null) {
      responseFuture.then((response) {
        _sendQueue.add(response);
        if (_sendQueue.length == 1) {
          _eventStream.enableWriteEvents();
        }
      });
    }
  }

  void _doWrite() {
    if (_sendQueue.length > 0) {
      assert(_eventStream.readyWrite);
      var responseMessage = _sendQueue.removeAt(0);
      _endpoint.write(responseMessage.buffer,
                      responseMessage.buffer.lengthInBytes,
                      responseMessage.handles);
      if (!_endpoint.status.isOk) {
        throw "message pipe write failed: ${_endpoint.status}";
      }
    }
  }

  StreamSubscription<int> listen() {
    _isOpen = true;
    return _eventStream.listen((List<int> event) {
      var signalsWatched = new core.MojoHandleSignals(event[0]);
      var signalsReceived = new core.MojoHandleSignals(event[1]);
      if (signalsReceived.isPeerClosed) {
        close();
        return;
      }

      if (signalsReceived.isReadable) {
        _doRead();
      }

      if (signalsReceived.isWritable) {
        _doWrite();
      }

      if (_sendQueue.length == 0) {
        var withoutWritable = signalsWatched - core.MojoHandleSignals.WRITABLE;
        _eventStream.enableSignals(withoutWritable);
      } else {
        _eventStream.enableSignals(signalsWatched);
      }
    });
  }

  void close() {
    // TODO(zra): Cancel outstanding Futures started in _doRead?
    if (_isOpen) {
      _eventStream.close();
      _isOpen = false;
      _eventStream = null;
    }
  }

  Message buildResponse(Type t, int name, Object response) {
    var builder = new MessageBuilder(name, align(getEncodedSize(t)));
    builder.encodeStruct(t, response);
    return builder.finish();
  }

  Message buildResponseWithID(
      Type t, int name, int id, int flags, Object response) {
    var builder = new MessageWithRequestIDBuilder(
        name, align(getEncodedSize(t)), id, flags);
    builder.encodeStruct(t, response);
    return builder.finish();
  }

  void enqueueMessage(Type t, int name, Object msg) {
    var builder = new MessageBuilder(name, align(getEncodedSize(t)));
    builder.encodeStruct(t, msg);
    var message = builder.finish();
    _sendQueue.add(message);
    _eventStream.enableWriteEvents();
  }

  Future enqueueMessageWithRequestID(Type t, int name, int id, Object msg) {
    // TODO(zra): Is this correct?
    throw "The client interface should not expect a response";
  }

  bool get isOpen => _isOpen;
  core.MojoMessagePipeEndpoint get endpoint => _endpoint;
}
