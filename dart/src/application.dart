// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of application;

// The Application interface doesn't explicitly have a Shell as a Client, but
// that is what is at the other end of the MessagePipe.
abstract class Application extends application.ApplicationInterface
                           with shell.ShellCalls {
  List<service_provider.ServiceProviderClient> _clients;

  Application(core.MojoMessagePipeEndpoint endpoint) :
      _clients = [],
      super(endpoint);

  Application.fromHandle(core.MojoHandle shellHandle) :
      _clients = [],
      super.fromHandle(shellHandle);

  Function interfaceFactoryClosure() => (endpoint) => null;

  void initialize(List<String> args) {
  }

  void acceptConnection(
      String requestorUrl,
      service_provider.ServiceProviderInterface services,
      service_provider.ServiceProviderClient exposedServices) {
    var closure = interfaceFactoryClosure();
    if (closure != null) {
      var serviceProvider = new ServiceProvider(closure);
      services.delegate = serviceProvider;
      services.listen();
    }
  }

  core.MojoMessagePipeEndpoint connectToService(String url, String service) {
    var applicationPipe = new core.MojoMessagePipe();
    var clientEndpoint = applicationPipe.endpoints[0];
    var applicationEndpoint = applicationPipe.endpoints[1];
    var serviceProviderClient =
        new service_provider.ServiceProviderClient.unbound();
    callConnectToApplication(url, serviceProviderClient, null);
    serviceProviderClient.callConnectToService(service, applicationEndpoint);
    _clients.add(serviceProviderClient);
    return clientEndpoint;
  }

  void close() {
    _clients.forEach((c) => c.close());
    _clients.clear();
    super.close();
  }
}
