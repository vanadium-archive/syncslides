// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:flutter/services.dart' show shell;
import 'package:mojo_services/input/input.mojom.dart';

String _inputMojoUrl = 'mojo:input';

typedef bool BackButtonHandler();

BackButtonHandler _handler;
// Registers a handler for the back button.
// Handler should return false when it no longer wants to control
// the behaviour of the back button, in which case the app will exit.
void onBackButton(BackButtonHandler handler) {
  if (_handler != null) {
    throw new ArgumentError("Only one back button handler can exist per app.");
  }

  InputServiceProxy inputService = new InputServiceProxy.unbound();
  shell.connectToService(_inputMojoUrl, inputService);

  InputClientStub intputClientStub = new InputClientStub.unbound();
  intputClientStub.impl = new _InputHandler();

  inputService.ptr.setClient(intputClientStub);
  _handler = handler;
}

class _InputHandler extends InputClient {
  dynamic onBackButton([Function responseFactory]) {
    // TODO(aghassemi): Currently there is no way to tell mojo:input service
    // to use the boolean returned by the handler to exit the app.
    // See https://github.com/domokit/mojo/issues/544
    _handler();
    return responseFactory();
  }
}
