// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of application;

// The Application interface doesn't explicitly have a Shell as a Client, but
// that is what is at the other end of the MessagePipe.
abstract class Application extends application.ApplicationStub
                           with shell.ShellCalls {
  List<service_provider.ServiceProviderProxy> _proxies;

  Application(core.MojoMessagePipeEndpoint endpoint) :
      _proxies = [],
      super(endpoint);

  Application.fromHandle(core.MojoHandle shellHandle) :
      _proxies = [],
      super.fromHandle(shellHandle);

  Function stubFactoryClosure() => (endpoint) => null;

  void initialize(List<String> args) {
  }

  void acceptConnection(
      String requestorUrl,
      service_provider.ServiceProviderStub services,
      service_provider.ServiceProviderProxy exposedServices) {
    var closure = stubFactoryClosure();
    if (closure != null) {
      var serviceProvider = new ServiceProvider(closure);
      services.delegate = serviceProvider;
      services.listen();
    }
  }

  void connectToService(String url, bindings.Proxy proxy) {
    assert(!proxy.isBound);
    var endpoint = _connectToServiceHelper(url, proxy.name);
    proxy.bind(endpoint);
  }

  core.MojoMessagePipeEndpoint _connectToServiceHelper(
      String url, String service) {
    var applicationPipe = new core.MojoMessagePipe();
    var proxyEndpoint = applicationPipe.endpoints[0];
    var applicationEndpoint = applicationPipe.endpoints[1];
    var serviceProviderProxy =
        new service_provider.ServiceProviderProxy.unbound();
    callConnectToApplication(url, serviceProviderProxy, null);
    serviceProviderProxy.callConnectToService(service, applicationEndpoint);
    _proxies.add(serviceProviderProxy);
    return proxyEndpoint;
  }

  void close() {
    _proxies.forEach((c) => c.close());
    _proxies.clear();
    super.close();
  }
}
