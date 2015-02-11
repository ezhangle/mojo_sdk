// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of application;

typedef core.Listener InterfaceFactory(core.MojoMessagePipeEndpoint endpoint);
typedef void FallbackInterfaceFactory(
        String interfaceName, core.MojoMessagePipeEndpoint endpoint);

// ServiceProvider implementation used to provide services to a remote
// application. Register a factory for service creation using either of the
// following:
// 1. When you know the interface use registerFactory(), e.g.
//    serviceProvider.registerFactory(ViewManagerClient.name, (pipe) =>
//        new ViewManagerClientImpl(pipe));
// 2. To handle requests for any interface set the FallbackFactory. The
//    FallbackFactory is passed the name of the requested interface.
//
// If a factory has been registered based on the name, it is used. If the
// factory returned null or there is no registered factory then the
// fallbackFactory is used. The fallbackFactory does not return a type; the
// factory takes ownership and if it does not want to use the pipe it must
// call close().
class ServiceProvider extends service_provider.ServiceProvider {
  FallbackInterfaceFactory fallbackFactory;

  service_provider.ServiceProviderProxy _proxy;

  Map<String, InterfaceFactory> _interfaceFactories;

  ServiceProvider(
      service_provider.ServiceProviderStub services,
      [service_provider.ServiceProviderProxy exposedServices = null])
      : _proxy = exposedServices,
        _interfaceFactories = new Map(),
        super.fromStub(services) {
    delegate = this;
  }

  connectToService(String interfaceName, core.MojoMessagePipeEndpoint pipe) {
    if (_interfaceFactories.containsKey(interfaceName)) {
      var listener = _interfaceFactories[interfaceName](pipe);
      if (listener != null) {
        listener.listen();
        return;
      }
    }
    if (fallbackFactory != null) {
      fallbackFactory(interfaceName, pipe);
      return;
    }
    // If we get here the interface isn't known. This is legal. Close the pipe
    // so the remote side sees we don't support this interface.
    pipe.handle.close();
  }

  requestService(String name, bindings.Proxy clientImpl) {
    assert(_proxy != null);
    assert(!clientImpl.isBound);
    var pipe = new core.MojoMessagePipe();
    clientImpl.bind(pipe.endpoints[0]);
    _proxy.connectToService(name, pipe.endpoints[1]);
  }

  registerFactory(String interfaceName, InterfaceFactory factory) {
    _interfaceFactories[interfaceName] = factory;
  }

  close({bool nodefer : false}) {
    if (_proxy != null) {
      _proxy.close();
      _proxy = null;
    }
    super.close(nodefer: nodefer);
  }
}
