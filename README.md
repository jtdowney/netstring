# netstring

[![Package Version](https://img.shields.io/hexpm/v/netstring)](https://hex.pm/packages/netstring)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/netstring/)

A Gleam library for encoding and decoding [netstrings](https://cr.yp.to/proto/netstrings.txt) - a simple format for encoding byte strings with explicit lengths.

## Installation

```sh
gleam add netstring
```

## Usage

### Encoding

```gleam
import netstring

netstring.encode(<<"hello">>)
// -> <<"5:hello,">>

netstring.encode(<<>>)
// -> <<"0:,">>

// Works with arbitrary binary data
netstring.encode(<<0, 255, 128>>)
// -> <<"3:", 0, 255, 128, ",">>
```

### Decoding

The decoder returns both the decoded data and any remaining bytes, making it suitable for streaming protocols:

```gleam
import netstring

netstring.decode(<<"5:hello,">>)
// -> Ok(#(<<"hello">>, <<>>))

// Multiple netstrings in a buffer
netstring.decode(<<"5:hello,5:world,">>)
// -> Ok(#(<<"hello">>, <<"5:world,">>))
```

### Handling Incomplete Data

When data is incomplete, the decoder returns `NeedMore` - buffer more data and try again:

```gleam
import netstring.{NeedMore}

netstring.decode(<<"5:hel">>)
// -> Error(NeedMore)
```

## Documentation

Full API documentation is available at [hexdocs.pm/netstring](https://hexdocs.pm/netstring).
