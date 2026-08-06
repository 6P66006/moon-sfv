/// Ordered-map operations for [`Parameters`] and [`SfDictionary`].
///
/// Both are ordered maps backed by an `Array`. Insertion order is
/// preserved; `set` replaces in place when the key already exists, which
/// implements RFC 9651's rule that duplicate keys on the wire collapse to
/// their last occurrence while keeping the position of the first
/// occurrence.

///|
/// An empty parameter map.
pub fn Parameters::new() -> Parameters {
  { entries: [] }
}

///|
/// The number of parameters.
pub fn Parameters::len(self : Parameters) -> Int {
  self.entries.length()
}

///|
/// Whether the parameter map is empty.
pub fn Parameters::is_empty(self : Parameters) -> Bool {
  self.entries.is_empty()
}

///|
/// Access by position.
pub fn Parameters::get_by_index(self : Parameters, i : Int) -> Parameter? {
  self.entries.get(i)
}

///|
/// Access by key; returns the stored value.
pub fn Parameters::get_by_key(self : Parameters, key : String) -> BareItem? {
  for i in 0..<self.entries.length() {
    if self.entries[i].key == key {
      return Some(self.entries[i].value)
    }
  }
  None
}

///|
/// Insert or replace (by key) a parameter. A duplicate key keeps its
/// original position and receives the new value, matching RFC 9651
/// §4.2.3.2.
pub fn Parameters::set(
  self : Parameters,
  key : String,
  value : BareItem,
) -> Unit {
  for i in 0..<self.entries.length() {
    if self.entries[i].key == key {
      self.entries[i] = { key, value }
      return
    }
  }
  self.entries.push({ key, value })
}

///|
/// The ordered list of (key, value) entries.
pub fn Parameters::entries(self : Parameters) -> Array[Parameter] {
  self.entries.copy()
}

///|
/// A list of the parameter keys, in order.
pub fn Parameters::keys(self : Parameters) -> Array[String] {
  let out : Array[String] = []
  for e in self.entries {
    out.push(e.key)
  }
  out
}

///|
/// An empty Dictionary.
pub fn SfDictionary::new() -> SfDictionary {
  { entries: [] }
}

///|
/// The number of members.
pub fn SfDictionary::len(self : SfDictionary) -> Int {
  self.entries.length()
}

///|
/// Whether the Dictionary is empty (i.e. the field should be omitted).
pub fn SfDictionary::is_empty(self : SfDictionary) -> Bool {
  self.entries.is_empty()
}

///|
/// Access a member by position.
pub fn SfDictionary::get_by_index(
  self : SfDictionary,
  i : Int,
) -> DictionaryEntry? {
  self.entries.get(i)
}

///|
/// Access a member by key.
pub fn SfDictionary::get_by_key(
  self : SfDictionary,
  key : String,
) -> ListMember? {
  for i in 0..<self.entries.length() {
    if self.entries[i].key == key {
      return Some(self.entries[i].value)
    }
  }
  None
}

///|
/// Insert or replace (by key) a member. A duplicate key keeps its original
/// position and receives the new value, matching RFC 9651 §4.2.2.
pub fn SfDictionary::set(
  self : SfDictionary,
  key : String,
  entry_member : ListMember,
) -> Unit {
  for i in 0..<self.entries.length() {
    if self.entries[i].key == key {
      self.entries[i] = { key, value: entry_member }
      return
    }
  }
  self.entries.push({ key, value: entry_member })
}

///|
/// The ordered list of (key, member) entries.
pub fn SfDictionary::entries(self : SfDictionary) -> Array[DictionaryEntry] {
  self.entries.copy()
}

///|
/// A list of the member keys, in order.
pub fn SfDictionary::keys(self : SfDictionary) -> Array[String] {
  let out : Array[String] = []
  for e in self.entries {
    out.push(e.key)
  }
  out
}
