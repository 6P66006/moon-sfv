/// The abstract data model of RFC 9651 Structured Field Values.
///
/// Every type in this module mirrors one abstract type from the RFC:
/// integers, decimals, strings, tokens, byte sequences, booleans, dates,
/// display strings, parameters, items, inner lists, lists, and
/// dictionaries. The wire format is *not* the abstract value; these types
/// are the abstract values that the parsers and serializers convert.
///
/// Ordered-map operations for Parameters and Dictionary live in
/// `ordered_map.mbt`.

///|
/// A bare item: one of the eight Structured Fields scalar types.
pub(all) enum BareItem {
  Integer(Int64)
  Decimal(SfDecimal)
  StringItem(String)
  Token(String)
  ByteSequence(Bytes)
  Boolean(Bool)
  Date(Int64)
  DisplayString(String)
} derive(Debug, Eq)

///|
/// A single key/value parameter.
pub(all) struct Parameter {
  key : String
  value : BareItem
} derive(Debug, Eq)

///|
/// An ordered map of parameters attached to an Item or Inner List.
///
/// Duplicate keys parsed from the wire collapse to their last occurrence
/// (RFC 9651 §4.2.3.2). The map preserves insertion order.
pub(all) struct Parameters {
  entries : Array[Parameter]
} derive(Debug, Eq)

///|
/// An Item: a bare item with associated parameters.
pub(all) struct Item {
  bare : BareItem
  parameters : Parameters
} derive(Debug, Eq)

///|
/// An Inner List: an ordered array of Items plus its own parameters.
pub(all) struct InnerList {
  items : Array[Item]
  parameters : Parameters
} derive(Debug, Eq)

///|
/// One member of a List or Dictionary: an Item or an Inner List.
pub(all) enum ListMember {
  ItemMember(Item)
  InnerListMember(InnerList)
} derive(Debug, Eq)

///|
/// A List: an ordered array of members.
pub(all) struct SfList {
  members : Array[ListMember]
} derive(Debug, Eq)

///|
/// One member of a Dictionary.
pub(all) struct DictionaryEntry {
  key : String
  value : ListMember
} derive(Debug, Eq)

///|
/// A Dictionary: an ordered map of key to member.
///
/// Duplicate keys parsed from the wire collapse to their last occurrence
/// (RFC 9651 §4.2.2). The map preserves insertion order.
pub(all) struct SfDictionary {
  entries : Array[DictionaryEntry]
} derive(Debug, Eq)

///|
/// The result of serializing a whole field. An empty List or Dictionary is
/// represented by omitting the field entirely (RFC 9651 §4.1 step 1), so
/// the result is [`Omit`] rather than an empty string, letting callers
/// distinguish "field omitted" from "field with an empty value".
pub(all) enum SerializedField {
  Omit
  Value(String)
} derive(Debug, Eq)

///|
/// Convenience constructors for bare items.
pub fn BareItem::integer(v : Int64) -> BareItem {
  Integer(v)
}

///|
pub fn BareItem::decimal(v : SfDecimal) -> BareItem {
  Decimal(v)
}

///|
pub fn BareItem::string_item(v : String) -> BareItem {
  StringItem(v)
}

///|
pub fn BareItem::token(v : String) -> BareItem {
  Token(v)
}

///|
pub fn BareItem::byte_sequence(v : Bytes) -> BareItem {
  ByteSequence(v)
}

///|
pub fn BareItem::boolean(v : Bool) -> BareItem {
  Boolean(v)
}

///|
pub fn BareItem::date(v : Int64) -> BareItem {
  Date(v)
}

///|
pub fn BareItem::display_string(v : String) -> BareItem {
  DisplayString(v)
}

///|
/// Convenience constructor for an Item from a bare item with no parameters.
pub fn Item::of(bare : BareItem) -> Item {
  { bare, parameters: Parameters::new() }
}

///|
/// Convenience constructor for an Item from a bare item and parameters.
pub fn Item::with_parameters(bare : BareItem, parameters : Parameters) -> Item {
  { bare, parameters }
}

///|
/// Convenience constructor for a member holding an Item.
pub fn ListMember::item(v : Item) -> ListMember {
  ItemMember(v)
}

///|
/// Convenience constructor for a member holding an Inner List.
pub fn ListMember::inner_list(v : InnerList) -> ListMember {
  InnerListMember(v)
}

///|
/// An empty Inner List.
pub fn InnerList::new() -> InnerList {
  { items: [], parameters: Parameters::new() }
}

///|
/// The number of Items in the Inner List.
pub fn InnerList::len(self : InnerList) -> Int {
  self.items.length()
}

///|
/// The ordered Items of an Inner List.
pub fn InnerList::items(self : InnerList) -> Array[Item] {
  self.items.copy()
}

///|
/// An empty List.
pub fn SfList::new() -> SfList {
  { members: [] }
}

///|
/// The number of members.
pub fn SfList::len(self : SfList) -> Int {
  self.members.length()
}

///|
/// Whether the List is empty (i.e. the field should be omitted).
pub fn SfList::is_empty(self : SfList) -> Bool {
  self.members.is_empty()
}

///|
/// Access a member by position.
pub fn SfList::get_by_index(self : SfList, i : Int) -> ListMember? {
  self.members.get(i)
}

///|
/// The ordered list of members.
pub fn SfList::members(self : SfList) -> Array[ListMember] {
  self.members.copy()
}
