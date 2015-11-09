// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// KeyValue presents a generic pair of key and value objects.
class KeyValue<T1, T2> {
  T1 key;
  T2 value;

  KeyValue(this.key, this.value);
}
