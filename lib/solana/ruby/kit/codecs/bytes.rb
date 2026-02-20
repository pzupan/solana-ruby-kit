# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Codecs
    # Low-level byte-string utilities.
    # All methods work with binary-encoded Ruby Strings (encoding = ASCII-8BIT).
    module Bytes
      extend T::Sig

      module_function

      # Concatenate multiple binary strings into one.
      sig { params(byte_strings: String).returns(String) }
      def merge_bytes(*byte_strings)
        result = ''.b
        byte_strings.each { |bs| result << bs.b }
        result
      end

      # Pad +bytes+ to exactly +size+ bytes.
      # @param direction [:right, :left]  which side to pad
      sig do
        params(bytes: String, size: Integer, direction: Symbol, pad_byte: String)
          .returns(String)
      end
      def pad_bytes(bytes, size, direction: :right, pad_byte: "\x00")
        b = bytes.b
        return b if b.bytesize >= size

        padding = (pad_byte.b * (size - b.bytesize))
        direction == :left ? padding + b : b + padding
      end

      # Return exactly +size+ bytes from +bytes+, raising if sizes don't match.
      sig { params(bytes: String, size: Integer).returns(String) }
      def fix_bytes(bytes, size)
        b = bytes.b
        unless b.bytesize == size
          Kernel.raise ArgumentError,
                "Expected #{size} bytes, got #{b.bytesize}"
        end

        b
      end

      # Return true if +inner+ appears inside +outer+ starting at +offset+.
      sig { params(outer: String, inner: String, offset: Integer).returns(T::Boolean) }
      def contains_bytes?(outer, inner, offset: 0)
        ob = outer.b
        ib = inner.b
        return false if offset + ib.bytesize > ob.bytesize

        ob.byteslice(offset, ib.bytesize) == ib
      end
    end
  end
end
