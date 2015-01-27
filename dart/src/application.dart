// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of application;

class ApplicationImpl implements application.ApplicationStub {
  shell_mojom.ShellProxy shell;
  Application _application;

  ApplicationImpl(this._application);

  void initialize(shell_mojom.ShellProxy shellProxy, List<String> args) {
    assert(shell == null);
    shell = shellProxy;
    _application.initialize(args);
  }

  void acceptConnection(
      String requestorUrl,
      service_provider.ServiceProviderStub services,
      service_provider.ServiceProviderProxy exposedServices) =>
      _application._acceptConnection(requestorUrl, services, exposedServices);

  void close() => shell.close();
}

// TODO(zra): Better documentation and examples.
// To implement, provide a stubFactoryClosure() that returns a function
// that takes a MojoMessagePipeEndpoint and returns a Stub that provides the
// Application's services. The function may return null if the Application
// provides no services. Optionally override initialize() when needed. Call
// listen() on a newly created Application to begin providing services. Call
// connectToService() to request services from the Shell. Calling close()
// closes connections to any requested ServiceProviders and the Shell.
abstract class Application {
  application.ApplicationStub _applicationStub;
  ApplicationImpl _applicationImpl;
  List<service_provider.ServiceProviderProxy> _proxies;

  Application(core.MojoMessagePipeEndpoint endpoint) {
    _proxies = [];
    _applicationImpl = new ApplicationImpl(this);
    _applicationStub = new application.ApplicationStub(endpoint)
                       ..delegate = _applicationImpl;
  }

  Application.fromHandle(core.MojoHandle appHandle) {
    _proxies = [];
    _applicationImpl = new ApplicationImpl(this);
    _applicationStub = new application.ApplicationStub.fromHandle(appHandle)
                       ..delegate = _applicationImpl;
  }

  Function stubFactoryClosure();

  void initialize(List<String> args) {}

  void connectToService(String url, bindings.Proxy proxy) {
    assert(!proxy.isBound);
    var endpoint = _connectToServiceHelper(url, proxy.name);
    proxy.bind(endpoint);
  }

  listen() => _applicationStub.listen();

  void close() {
    assert(_proxies != null);
    assert(_applicationImpl != null);
    _proxies.forEach((c) => c.close());
    _proxies.clear();
    _applicationImpl.close();
  }

  void _acceptConnection(
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

  core.MojoMessagePipeEndpoint _connectToServiceHelper(
      String url, String service) {
    var applicationPipe = new core.MojoMessagePipe();
    var proxyEndpoint = applicationPipe.endpoints[0];
    var applicationEndpoint = applicationPipe.endpoints[1];
    var serviceProviderProxy =
        new service_provider.ServiceProviderProxy.unbound();
    _applicationImpl.shell.callConnectToApplication(
        url, serviceProviderProxy, null);
    serviceProviderProxy.callConnectToService(service, applicationEndpoint);
    _proxies.add(serviceProviderProxy);
    return proxyEndpoint;
  }
}
