// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of application;

typedef core.Listener ListenerFactory(core.MojoMessagePipeEndpoint endpoint);
typedef core.Listener FallbackListenerFactory(
        String interfaceName, core.MojoMessagePipeEndpoint endpoint);

class ServiceProvider extends service_provider.ServiceProvider {
  FallbackListenerFactory fallbackFactory;

  service_provider.ServiceProviderProxy _proxy;

  Map<String, ListenerFactory> _interfaceFactories;

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
      var listener = fallbackFactory(interfaceName, pipe);
      if (listener != null) {
        listener.listen();
        return;
      }
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

  registerFactory(String interfaceName, ListenerFactory factory) {
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
