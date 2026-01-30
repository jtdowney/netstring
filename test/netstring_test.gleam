import gleam/bit_array
import gleam/bytes_tree
import netstring
import unitest

pub fn main() -> Nil {
  unitest.main()
}

pub fn encode_basic_test() {
  let result = netstring.encode(<<"hello">>)
  assert result == <<"5:hello,">>
}

pub fn encode_empty_test() {
  let result = netstring.encode(<<>>)
  assert result == <<"0:,">>
}

pub fn encode_binary_data_test() {
  let result = netstring.encode(<<0, 255, 128>>)
  assert result == <<"3:", 0, 255, 128, ",">>
}

pub fn decode_returns_bitarray_test() {
  let buffer = bit_array.from_string("5:hello,")
  let assert Ok(#(data, remaining)) = netstring.decode(buffer)
  assert data == <<"hello">>
  assert remaining == <<>>
}

pub fn decode_multiple_frames_test() {
  let buffer = bit_array.from_string("5:hello,5:world,")
  let assert Ok(#(first, remaining)) = netstring.decode(buffer)
  assert first == <<"hello">>

  let assert Ok(#(second, final)) = netstring.decode(remaining)
  assert second == <<"world">>
  assert final == <<>>
}

pub fn decode_incomplete_test() {
  let buffer = bit_array.from_string("5:hel")
  assert netstring.decode(buffer) == Error(netstring.NeedMore)
}

pub fn decode_utf8_bytes_test() {
  let buffer = bit_array.from_string("6:你好,")
  let assert Ok(#(data, _)) = netstring.decode(buffer)
  assert data == <<"你好">>
}

pub fn decode_empty_data_test() {
  let buffer = bit_array.from_string("0:,")
  let assert Ok(#(data, remaining)) = netstring.decode(buffer)
  assert data == <<>>
  assert remaining == <<>>
}

pub fn decode_invalid_format_no_colon_test() {
  let buffer = bit_array.from_string("5hello,")
  let assert Error(netstring.InvalidFormat(_)) = netstring.decode(buffer)
}

pub fn decode_invalid_format_no_comma_test() {
  let buffer = bit_array.from_string("5:hello")
  assert netstring.decode(buffer) == Error(netstring.NeedMore)
}

pub fn decode_non_utf8_binary_test() {
  let buffer = <<"3:", 0, 255, 128, ",">>
  let assert Ok(#(data, remaining)) = netstring.decode(buffer)
  assert data == <<0, 255, 128>>
  assert remaining == <<>>
}

pub fn roundtrip_test() {
  let original = <<0, 1, 2, 255, 254, 253>>
  let encoded = netstring.encode(original)
  let assert Ok(#(decoded, <<>>)) = netstring.decode(encoded)
  assert decoded == original
}

pub fn decode_rejects_empty_length_test() {
  let buffer = bit_array.from_string(":,")
  let assert Error(netstring.InvalidFormat(_)) = netstring.decode(buffer)
}

pub fn decode_rejects_leading_zeros_test() {
  let buffer = bit_array.from_string("00:,")
  let assert Error(netstring.InvalidFormat(_)) = netstring.decode(buffer)
}

pub fn decode_rejects_leading_zeros_with_data_test() {
  let buffer = bit_array.from_string("07:hello,,")
  let assert Error(netstring.InvalidFormat(_)) = netstring.decode(buffer)
}

pub fn decode_rejects_wrong_trailing_byte_test() {
  let buffer = bit_array.from_string("5:hello;")
  let assert Error(netstring.InvalidFormat(_)) = netstring.decode(buffer)
}

pub fn encode_tree_test() {
  let tree = bytes_tree.from_string("hello")
  let result = netstring.encode_tree(tree)
  assert bytes_tree.to_bit_array(result) == <<"5:hello,">>
}
