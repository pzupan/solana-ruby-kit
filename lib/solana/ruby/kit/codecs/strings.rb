# typed: strict
# frozen_string_literal: true

require 'base64'

module Solana::Ruby::Kit
  module Codecs
    # String codecs — mirrors @solana/codecs-strings.
    module Strings
      extend T::Sig

      module_function

      # UTF-8 string codec.
      # When +size+ is given the encoded bytes are fixed to that length
      # (zero-padded or truncated); otherwise the codec is variable-length
      # and must be used inside a size-prefixed container.
      sig { params(size: T.nilable(Integer)).returns(Codec) }
      def utf8_codec(size: nil)
        enc = Encoder.new(fixed_size: size) do |v|
          raw = v.to_s.encode('UTF-8').b
          if size
            raw.bytesize <= size ? raw.ljust(size, "\x00") : raw.byteslice(0, size) || ''.b
          else
            raw
          end
        end
        dec = Decoder.new(fixed_size: size) do |bytes, offset|
          len   = size || (bytes.bytesize - offset)
          slice = bytes.b.byteslice(offset, len) || ''.b
          # Strip null padding for fixed-size strings
          str   = size ? slice.delete_suffix("\x00" * slice.bytesize.times.take_while { |i| slice.b[-1 - i] == "\x00" }.length) : slice
          [str.force_encoding('UTF-8'), len]
        end
        Codec.new(enc, dec)
      end

      # Base58 codec — uses Solana::Ruby::Kit::Encoding::Base58.
      sig { returns(Codec) }
      def base58_codec
        enc = Encoder.new do |v|
          Solana::Ruby::Kit::Encoding::Base58.decode(v.to_s)
        end
        dec = Decoder.new do |bytes, offset|
          remaining = bytes.b.byteslice(offset..) || ''.b
          [Solana::Ruby::Kit::Encoding::Base58.encode(remaining), remaining.bytesize]
        end
        Codec.new(enc, dec)
      end

      # Base64 codec — strict (no newlines).
      sig { returns(Codec) }
      def base64_codec
        enc = Encoder.new do |v|
          Base64.strict_encode64(v.to_s)
        end
        dec = Decoder.new do |bytes, offset|
          remaining = bytes.b.byteslice(offset..) || ''.b
          [Base64.strict_decode64(remaining.force_encoding('ASCII')), remaining.bytesize]
        end
        Codec.new(enc, dec)
      end

      # Hex codec — lower-case hex string ↔ binary bytes.
      sig { returns(Codec) }
      def hex_codec
        enc = Encoder.new do |v|
          [v.to_s.tr(' ', '')].pack('H*')
        end
        dec = Decoder.new do |bytes, offset|
          remaining = bytes.b.byteslice(offset..) || ''.b
          [remaining.unpack1('H*'), remaining.bytesize]
        end
        Codec.new(enc, dec)
      end

      # Fixed-size raw bytes passthrough.
      sig { params(size: Integer).returns(Codec) }
      def bytes_codec(size)
        enc = Encoder.new(fixed_size: size) do |v|
          b = v.is_a?(String) ? v.b : v.to_s.b
          Kernel.raise ArgumentError, "Expected #{size} bytes, got #{b.bytesize}" if b.bytesize != size

          b
        end
        dec = Decoder.new(fixed_size: size) do |bytes, offset|
          slice = bytes.b.byteslice(offset, size) || ''.b
          [slice, size]
        end
        Codec.new(enc, dec)
      end

      # Bit-array codec.
      # Encodes an Array of booleans into +size+ bytes (LSB-first within each byte).
      sig { params(size: Integer).returns(Codec) }
      def bit_array_codec(size)
        total_bits = size * 8
        enc = Encoder.new(fixed_size: size) do |bits|
          arr   = T.cast(bits, T::Array[T::Boolean])
          bytes = Array.new(size, 0)
          arr.first(total_bits).each_with_index do |bit, idx|
            bytes[idx / 8] |= (1 << (idx % 8)) if bit
          end
          bytes.pack('C*')
        end
        dec = Decoder.new(fixed_size: size) do |bytes, offset|
          slice = bytes.b.byteslice(offset, size) || ''.b
          byte_arr = T.cast(T.unsafe(slice).unpack('C*'), T::Array[Integer])
          bits = byte_arr.flat_map { |byte| 8.times.map { |i| byte[i] == 1 } }
          [bits, size]
        end
        Codec.new(enc, dec)
      end
    end
  end
end
