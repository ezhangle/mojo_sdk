// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "mojo/public/cpp/application/application_test_base.h"

#include "mojo/public/cpp/application/application_delegate.h"
#include "mojo/public/cpp/application/application_impl.h"
#include "mojo/public/cpp/environment/environment.h"
#include "mojo/public/cpp/system/message_pipe.h"

namespace mojo {
namespace test {

namespace {

// This shell handle is shared by multiple test application instances.
ShellPtr g_shell;
// Share the application command-line arguments with multiple application tests.
Array<String> g_args;

class ArgumentGrabber : public InterfaceImpl<Application> {
 public:
  ArgumentGrabber(Array<String>* args, ShellPtr shell)
      : args_(args), shell_(shell.Pass()) {
    shell_.set_client(this);
  }

  void WaitForInitialize() {
    // Initialize is always the first call made on Application.
    shell_.WaitForIncomingMethodCall();
  }

  ShellPtr UnbindShell() {
    ShellPtr unbound_shell;
    unbound_shell.Bind(shell_.PassMessagePipe());
    return unbound_shell.Pass();
  }

 private:
  // Application implementation.
  void Initialize(Array<String> args) override { *args_ = args.Pass(); }

  void AcceptConnection(const String& requestor_url,
                        InterfaceRequest<ServiceProvider> services,
                        ServiceProviderPtr exposed_services) override {
    MOJO_CHECK(false);
  }

  void RequestQuit() override { MOJO_CHECK(false); }

  Array<String>* args_;
  ShellPtr shell_;
};

ShellPtr PassShellHandle() {
  MOJO_CHECK(g_shell);
  return g_shell.Pass();
}

void SetShellHandle(ShellPtr shell) {
  MOJO_CHECK(shell);
  MOJO_CHECK(!g_shell);
  g_shell = shell.Pass();
}

void InitializeArgs(int argc, std::vector<const char*> argv) {
  MOJO_CHECK(g_args.is_null());
  for (const char* arg : argv) {
    if (arg)
      g_args.push_back(arg);
  }
}

}  // namespace

const Array<String>& Args() {
  return g_args;
}

MojoResult RunAllTests(ShellPtr shell) {
  {
    // This loop is used for init, and then destroyed before running tests.
    Environment::InstantiateDefaultRunLoop();

    Array<String> args;
    ArgumentGrabber grab(&args, shell.Pass());
    grab.WaitForInitialize();

    // InitGoogleTest expects (argc + 1) elements, including a terminating null.
    // It also removes GTEST arguments from |argv| and updates the |argc| count.
    MOJO_CHECK(args.size() <
               static_cast<size_t>(std::numeric_limits<int>::max()));
    int argc = static_cast<int>(args.size());
    std::vector<const char*> argv(argc + 1);
    for (int i = 0; i < argc; ++i)
      argv[i] = args[i].get().c_str();
    argv[argc] = nullptr;

    testing::InitGoogleTest(&argc, const_cast<char**>(&(argv[0])));
    SetShellHandle(grab.UnbindShell());
    InitializeArgs(argc, argv);

    Environment::DestroyDefaultRunLoop();
  }

  int result = RUN_ALL_TESTS();

  shell = mojo::test::PassShellHandle();
  shell.reset();

  return (result == 0) ? MOJO_RESULT_OK : MOJO_RESULT_UNKNOWN;
}

ApplicationTestBase::ApplicationTestBase() : application_impl_(nullptr) {
}

ApplicationTestBase::~ApplicationTestBase() {
}

ApplicationDelegate* ApplicationTestBase::GetApplicationDelegate() {
  return &default_application_delegate_;
}

void ApplicationTestBase::SetUpWithArgs(const Array<String>& args) {
  // A run loop is recommended for ApplicationImpl initialization and
  // communication.
  if (ShouldCreateDefaultRunLoop())
    Environment::InstantiateDefaultRunLoop();

  // New applications are constructed for each test to avoid persisting state.
  application_impl_ = new ApplicationImpl(GetApplicationDelegate(),
                                          PassShellHandle());

  // Fake application initialization with the given command line arguments.
  application_impl_->Initialize(args.Clone());
}

void ApplicationTestBase::SetUp() {
  SetUpWithArgs(Args());
}

void ApplicationTestBase::TearDown() {
  SetShellHandle(application_impl_->UnbindShell());
  delete application_impl_;
  if (ShouldCreateDefaultRunLoop())
    Environment::DestroyDefaultRunLoop();
}

bool ApplicationTestBase::ShouldCreateDefaultRunLoop() {
  return true;
}

}  // namespace test
}  // namespace mojo
