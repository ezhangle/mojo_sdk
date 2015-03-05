// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of application;

class _ApplicationImpl implements application_mojom.Application {
  application_mojom.ApplicationStub _stub;
  shell_mojom.ShellProxy shell;
  Application _application;

  _ApplicationImpl(Application application,
      core.MojoMessagePipeEndpoint endpoint, {Function onClosed}) {
    _application = application;
    // We wrap the onClosed callback in a closure to ensure that all
    // necessary cleanup is performed on a PEER_CLOSED signal.
    _stub = new application_mojom.ApplicationStub.fromEndpoint(
        endpoint,
        impl: this,
        onClosed: _closer(onClosed));
  }

  _ApplicationImpl.fromHandle(Application application, core.MojoHandle handle,
      {Function onClosed}) {
    _application = application;
    _stub = new application_mojom.ApplicationStub.fromHandle(
        handle,
        impl: this,
        onClosed: _closer(onClosed));
  }

  void initialize(bindings.ProxyBase shellProxy, List<String> args,
      String url) {
    assert(shell == null);
    shell = shellProxy;
    _application.initialize(args, url);
  }

  @override
  void acceptConnection(String requestorUrl, ServiceProviderStub services,
      bindings.ProxyBase exposedServices, String resolvedUrl) =>
      _application._acceptConnection(
          requestorUrl,
          services,
          exposedServices,
          resolvedUrl);

  @override
  void requestQuit() => _application._requestQuitAndClose();

  Function _closer(Function onClosed) {
    return (() {
      if (onClosed != null) {
        onClosed();
      }
      close();
    });
  }

  void close({bool nodefer: false}) {
    shell.close();
    _stub.close();
  }
}

// TODO(zra): Better documentation and examples.
// To implement, do the following:
// - Optionally override initialize() to process command-line args.
// - Optionally override acceptConnection() if services are to be provided.
// - Optionally override close() to clean up application resources.
abstract class Application {
  _ApplicationImpl _applicationImpl;
  List<ApplicationConnection> _applicationConnections;

  Application(core.MojoMessagePipeEndpoint endpoint, {Function onClosed}) {
    _applicationConnections = [];
    // We wrap the onClosed callback in a closure to ensure that all
    // necessary cleanup is performed on a PEER_CLOSED signal.
    _applicationImpl =
        new _ApplicationImpl(this, endpoint, onClosed: _closer(onClosed));
  }

  Application.fromHandle(core.MojoHandle appHandle, {Function onClosed}) {
    _applicationConnections = [];
    _applicationImpl =
        new _ApplicationImpl.fromHandle(this, appHandle, onClosed: _closer(onClosed));
  }

  void initialize(List<String> args, String url) {}

  // TODO(skydart): This is a temporary fix to allow sky application to consume
  // mojo services. Do not use for any other purpose.
  void initializeFromShellProxy(shell_mojom.ShellProxy shellProxy,
      List<String> args, String url) =>
      _applicationImpl.initialize(shellProxy, args, url);

  // Returns a connection to the app at |url|.
  ApplicationConnection connectToApplication(String url) {
    var proxy = new ServiceProviderProxy.unbound();
    var stub = new ServiceProviderStub.unbound();
    _applicationImpl.shell.ptr.connectToApplication(url, proxy, stub);
    var connection = new ApplicationConnection(stub, proxy);
    _applicationConnections.add(connection);
    return connection;
  }

  void connectToService(String url, bindings.ProxyBase proxy) {
    connectToApplication(url).requestService(proxy);
  }

  void requestQuit() {}

  void _requestQuitAndClose() {
    requestQuit();
    close();
  }

  Function _closer(Function onClose) {
    return (() {
      if (onClose != null) {
        onClose();
      }
      close();
    });
  }

  void close() {
    assert(_applicationImpl != null);
    _applicationConnections.forEach((c) => c.close());
    _applicationConnections.clear();
    _applicationImpl.close();
  }

  // This method closes all the application connections. Used during apptesting.
  resetConnections() {
    assert(_applicationImpl != null);
    _applicationConnections.forEach((c) => c.close());
    _applicationConnections.clear();
  }

  void _acceptConnection(String requestorUrl, ServiceProviderStub services,
      ServiceProviderProxy exposedServices, String resolvedUrl) {
    var connection = new ApplicationConnection(services, exposedServices);
    _applicationConnections.add(connection);
    acceptConnection(requestorUrl, resolvedUrl, connection);
  }

  // Override this method to provide services on |connection|.
  // If you provide at least one service or set fallbackServiceProvider,
  // then you must invoke connection.listen().
  void acceptConnection(String requestorUrl, String resolvedUrl,
      ApplicationConnection connection) {
  }
}
