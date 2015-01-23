// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of application;

typedef bindings.Stub StubFactory(
    core.MojoMessagePipeEndpoint endpoint);

class ServiceProvider implements service_provider.ServiceProviderStub {
  StubFactory _stubFactory;

  ServiceProvider(this._stubFactory);

  connectToService(String interfaceName, core.MojoMessagePipeEndpoint pipe) {
    var stubImpl = _stubFactory(pipe);
    stubImpl.listen();
  }
}
