# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Codecs
    # Numeric codecs — mirrors @solana/codecs-numbers.
    # All pack/unpack directives follow Ruby's Array#pack notation.
    # Default endian is :little (Solana is always little-endian on-chain).
    #
    # Fixed sizes (bytes):
    #   u8/i8 = 1, u16/i16 = 2, u32/i32 = 4, u64/i64 = 8,
    #   u128/i128 = 16, f32 = 4, f64 = 8
    module Numbers
      extend T::Sig

      module_function

      # ── Unsigned integers ────────────────────────────────────────────────────

      sig { returns(Codec) }
      def u8_codec
        enc = Encoder.new(fixed_size: 1) { |v| [Kernel.Integer(v)].pack('C') }
        dec = Decoder.new(fixed_size: 1) do |bytes, offset|
          [bytes.b.byteslice(offset, 1)&.unpack1('C') || 0, 1]
        end
        Codec.new(enc, dec)
      end

      sig { params(endian: Symbol).returns(Codec) }
      def u16_codec(endian: :little)
        dir = endian == :little ? 'v' : 'n'
        enc = Encoder.new(fixed_size: 2) { |v| [Kernel.Integer(v)].pack(dir) }
        dec = Decoder.new(fixed_size: 2) do |bytes, offset|
          [bytes.b.byteslice(offset, 2)&.unpack1(dir) || 0, 2]
        end
        Codec.new(enc, dec)
      end

      sig { params(endian: Symbol).returns(Codec) }
      def u32_codec(endian: :little)
        dir = endian == :little ? 'V' : 'N'
        enc = Encoder.new(fixed_size: 4) { |v| [Kernel.Integer(v)].pack(dir) }
        dec = Decoder.new(fixed_size: 4) do |bytes, offset|
          [bytes.b.byteslice(offset, 4)&.unpack1(dir) || 0, 4]
        end
        Codec.new(enc, dec)
      end

      sig { params(endian: Symbol).returns(Codec) }
      def u64_codec(endian: :little)
        dir = endian == :little ? 'Q<' : 'Q>'
        enc = Encoder.new(fixed_size: 8) { |v| [Kernel.Integer(v)].pack(dir) }
        dec = Decoder.new(fixed_size: 8) do |bytes, offset|
          [bytes.b.byteslice(offset, 8)&.unpack1(dir) || 0, 8]
        end
        Codec.new(enc, dec)
      end

      sig { params(endian: Symbol).returns(Codec) }
      def u128_codec(endian: :little)
        enc = Encoder.new(fixed_size: 16) do |v|
          n = Kernel.Integer(v)
          if endian == :little
            bytes = []
            16.times { bytes << (n & 0xFF); n >>= 8 }
            bytes.pack('C*')
          else
            bytes = []
            16.times { bytes.unshift(n & 0xFF); n >>= 8 }
            bytes.pack('C*')
          end
        end
        dec = Decoder.new(fixed_size: 16) do |bytes, offset|
          slice = bytes.b.byteslice(offset, 16) || ("\x00" * 16).b
          arr   = T.cast(T.unsafe(slice).unpack('C*'), T::Array[Integer])
          n = if endian == :little
                arr.reverse.reduce(0) { |acc, b| (acc << 8) | b }
              else
                arr.reduce(0) { |acc, b| (acc << 8) | b }
              end
          [n, 16]
        end
        Codec.new(enc, dec)
      end

      # ── Signed integers ──────────────────────────────────────────────────────

      sig { returns(Codec) }
      def i8_codec
        enc = Encoder.new(fixed_size: 1) { |v| [Kernel.Integer(v)].pack('c') }
        dec = Decoder.new(fixed_size: 1) do |bytes, offset|
          [bytes.b.byteslice(offset, 1)&.unpack1('c') || 0, 1]
        end
        Codec.new(enc, dec)
      end

      sig { params(endian: Symbol).returns(Codec) }
      def i16_codec(endian: :little)
        dir = endian == :little ? 's<' : 's>'
        enc = Encoder.new(fixed_size: 2) { |v| [Kernel.Integer(v)].pack(dir) }
        dec = Decoder.new(fixed_size: 2) do |bytes, offset|
          [bytes.b.byteslice(offset, 2)&.unpack1(dir) || 0, 2]
        end
        Codec.new(enc, dec)
      end

      sig { params(endian: Symbol).returns(Codec) }
      def i32_codec(endian: :little)
        dir = endian == :little ? 'l<' : 'l>'
        enc = Encoder.new(fixed_size: 4) { |v| [Kernel.Integer(v)].pack(dir) }
        dec = Decoder.new(fixed_size: 4) do |bytes, offset|
          [bytes.b.byteslice(offset, 4)&.unpack1(dir) || 0, 4]
        end
        Codec.new(enc, dec)
      end

      sig { params(endian: Symbol).returns(Codec) }
      def i64_codec(endian: :little)
        dir = endian == :little ? 'q<' : 'q>'
        enc = Encoder.new(fixed_size: 8) { |v| [Kernel.Integer(v)].pack(dir) }
        dec = Decoder.new(fixed_size: 8) do |bytes, offset|
          [bytes.b.byteslice(offset, 8)&.unpack1(dir) || 0, 8]
        end
        Codec.new(enc, dec)
      end

      sig { params(endian: Symbol).returns(Codec) }
      def i128_codec(endian: :little)
        enc = Encoder.new(fixed_size: 16) do |v|
          n    = Kernel.Integer(v)
          # Two's complement for negative numbers
          n += (1 << 128) if n.negative?
          if endian == :little
            bytes = []
            16.times { bytes << (n & 0xFF); n >>= 8 }
            bytes.pack('C*')
          else
            bytes = []
            16.times { bytes.unshift(n & 0xFF); n >>= 8 }
            bytes.pack('C*')
          end
        end
        dec = Decoder.new(fixed_size: 16) do |bytes, offset|
          slice = bytes.b.byteslice(offset, 16) || ("\x00" * 16).b
          arr   = T.cast(T.unsafe(slice).unpack('C*'), T::Array[Integer])
          n = if endian == :little
                arr.reverse.reduce(0) { |acc, b| (acc << 8) | b }
              else
                arr.reduce(0) { |acc, b| (acc << 8) | b }
              end
          # Convert from unsigned to signed 128-bit
          n -= (1 << 128) if n >= (1 << 127)
          [n, 16]
        end
        Codec.new(enc, dec)
      end

      # ── Floating point ───────────────────────────────────────────────────────

      sig { params(endian: Symbol).returns(Codec) }
      def f32_codec(endian: :little)
        dir = endian == :little ? 'e' : 'g'
        enc = Encoder.new(fixed_size: 4) { |v| [Kernel.Float(v)].pack(dir) }
        dec = Decoder.new(fixed_size: 4) do |bytes, offset|
          [bytes.b.byteslice(offset, 4)&.unpack1(dir) || 0.0, 4]
        end
        Codec.new(enc, dec)
      end

      sig { params(endian: Symbol).returns(Codec) }
      def f64_codec(endian: :little)
        dir = endian == :little ? 'E' : 'G'
        enc = Encoder.new(fixed_size: 8) { |v| [Kernel.Float(v)].pack(dir) }
        dec = Decoder.new(fixed_size: 8) do |bytes, offset|
          [bytes.b.byteslice(offset, 8)&.unpack1(dir) || 0.0, 8]
        end
        Codec.new(enc, dec)
      end

      # ── Short vector (Solana compact-u16) ────────────────────────────────────
      # Variable-length encoding used in transaction wire format.
      # Each byte uses the 7 low bits for data and bit 7 as a continuation flag.

      sig { returns(Codec) }
      def compact_u16_codec
        enc = Encoder.new do |v|
          n = Kernel.Integer(v)
          Kernel.raise ArgumentError, "compact_u16 value out of range: #{n}" if n > 0xFFFF || n.negative?

          bytes = []
          Kernel.loop do
            low7 = n & 0x7F
            n >>= 7
            bytes << (n.positive? ? (low7 | 0x80) : low7)
            break if n.zero?
          end
          bytes.pack('C*')
        end
        dec = Decoder.new do |bytes, offset|
          b  = bytes.b
          n  = 0
          shift = 0
          consumed = 0
          Kernel.loop do
            byte = b.byteslice(offset + consumed, 1)&.unpack1('C') || 0
            consumed += 1
            n |= (byte & 0x7F) << shift
            shift += 7
            break if (byte & 0x80).zero?
          end
          [n, consumed]
        end
        Codec.new(enc, dec)
      end
    end
  end
end
