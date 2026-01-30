//// A library for encoding and decoding [netstrings](https://cr.yp.to/proto/netstrings.txt).
////
//// Netstrings are a simple format for encoding byte strings with explicit lengths,
//// using the format `<length>:<data>,`. For example, `<<"hello">>` encodes as `<<"5:hello,">>`.

import gleam/bit_array
import gleam/bool
import gleam/bytes_tree.{type BytesTree}
import gleam/int
import gleam/result

/// Errors that can occur when decoding a netstring.
pub type NetstringError {
  /// The buffer doesn't contain a complete netstring yet.
  /// Buffer more data and call `decode` again.
  NeedMore
  /// The input is malformed. The `String` describes what was wrong.
  InvalidFormat(String)
}

/// Encodes a `BitArray` as a netstring.
///
/// ## Examples
///
/// ```gleam
/// netstring.encode(<<"hello">>)
/// // -> <<"5:hello,">>
///
/// netstring.encode(<<>>)
/// // -> <<"0:,">>
/// ```
pub fn encode(data: BitArray) -> BitArray {
  let length = bit_array.byte_size(data)
  let length_str = int.to_string(length)
  bit_array.concat([<<length_str:utf8, ":">>, data, <<",">>])
}

/// Encodes a `BytesTree` as a netstring, returning a `BytesTree`.
///
/// ## Examples
///
/// ```gleam
/// bytes_tree.from_string("hello")
/// |> netstring.encode_tree
/// |> bytes_tree.to_bit_array
/// // -> <<"5:hello,">>
/// ```
pub fn encode_tree(data: BytesTree) -> BytesTree {
  let length = bytes_tree.byte_size(data)
  int.to_string(length)
  |> bytes_tree.from_string
  |> bytes_tree.append_string(":")
  |> bytes_tree.append_tree(data)
  |> bytes_tree.append_string(",")
}

/// Decodes a netstring from a `BitArray` buffer.
///
/// On success, returns both the decoded data and any remaining bytes in the buffer.
/// This makes it suitable for streaming protocols where multiple netstrings may arrive
/// in a single buffer, or where data arrives incrementally.
///
/// ## Examples
///
/// ```gleam
/// netstring.decode(<<"5:hello,">>)
/// // -> Ok(#(<<"hello">>, <<>>))
///
/// // Multiple netstrings - remaining bytes returned for next decode
/// netstring.decode(<<"5:hello,5:world,">>)
/// // -> Ok(#(<<"hello">>, <<"5:world,">>))
///
/// // Incomplete data - buffer more and try again
/// netstring.decode(<<"5:hel">>)
/// // -> Error(NeedMore)
///
/// // Malformed input
/// netstring.decode(<<"hello">>)
/// // -> Error(InvalidFormat("Invalid character in length"))
/// ```
pub fn decode(buffer: BitArray) -> Result(#(BitArray, BitArray), NetstringError) {
  decode_bytes_inner(buffer, 0, 0, 0)
}

fn decode_bytes_inner(
  buffer: BitArray,
  index: Int,
  acc: Int,
  digit_count: Int,
) -> Result(#(BitArray, BitArray), NetstringError) {
  case bit_array.slice(buffer, index, 1) {
    Ok(<<":">>) if digit_count == 0 -> Error(InvalidFormat("Missing length"))
    Ok(<<":">>) -> extract_data_bits(buffer, index + 1, acc)
    Ok(<<digit>>) if digit >= 48 && digit <= 57 ->
      case digit_count >= 1 && acc == 0 {
        True -> Error(InvalidFormat("Leading zeros not allowed"))
        False ->
          decode_bytes_inner(
            buffer,
            index + 1,
            acc * 10 + digit - 48,
            digit_count + 1,
          )
      }
    Ok(_) -> Error(InvalidFormat("Invalid character in length"))
    Error(Nil) -> Error(NeedMore)
  }
}

fn extract_data_bits(
  buffer: BitArray,
  data_start: Int,
  length: Int,
) -> Result(#(BitArray, BitArray), NetstringError) {
  let buffer_size = bit_array.byte_size(buffer)
  use <- bool.guard(buffer_size < data_start + length + 1, Error(NeedMore))

  use data_bytes <- result.try(
    bit_array.slice(buffer, data_start, length)
    |> result.replace_error(NeedMore),
  )

  use <- bool.guard(
    bit_array.slice(buffer, data_start + length, 1) != Ok(<<44>>),
    Error(InvalidFormat("Missing trailing comma")),
  )

  let remaining_start = data_start + length + 1
  let remaining_len = buffer_size - remaining_start

  case bit_array.slice(buffer, remaining_start, remaining_len) {
    Ok(remaining_bytes) -> Ok(#(data_bytes, remaining_bytes))
    Error(Nil) -> Ok(#(data_bytes, <<>>))
  }
}
