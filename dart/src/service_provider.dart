// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of application;

typedef bindings.Interface InterfaceFactory(
    core.MojoMessagePipeEndpoint endpoint);

class ServiceProvider implements service_provider.ServiceProviderInterface {
  InterfaceFactory _interfaceFactory;

  ServiceProvider(this._interfaceFactory);

  connectToService(String interfaceName, core.MojoMessagePipeEndpoint pipe) {
    var interfaceImpl = _interfaceFactory(pipe);
    interfaceImpl.listen();
  }
}
