// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

const String existsErrorId = 'v.io/v23/verror.Exist';

// TODO(aghassemi): Export mojo.Error in Syncbase and use the type here.
bool isExistsError(e) {
  return e != null && (e.id == existsErrorId);
}
