# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Codecs
    # Mirrors the TypeScript Encoder<T> interface from @solana/codecs-core.
    #
    # An Encoder knows how to turn a Ruby value into a binary String.
    # Fixed-size encoders advertise their byte length via +fixed_size+;
    # variable-size encoders leave it nil and may advertise +max_size+.
    class Encoder
      extend T::Sig

      sig { returns(T.nilable(Integer)) }
      attr_reader :fixed_size

      sig { returns(T.nilable(Integer)) }
      attr_reader :max_size

      sig do
        params(
          fixed_size: T.nilable(Integer),
          max_size:   T.nilable(Integer),
          block:      T.proc.params(value: T.untyped).returns(String)
        ).void
      end
      def initialize(fixed_size: nil, max_size: nil, &block)
        @fixed_size = fixed_size
        @max_size   = max_size
        @fn         = T.let(block, T.proc.params(value: T.untyped).returns(String))
      end

      # Encode +value+ and return a binary String.
      sig { params(value: T.untyped).returns(String) }
      def encode(value)
        @fn.call(value).b
      end

      # Encode +value+ into +target+ starting at +offset+.
      # Returns the number of bytes written.
      sig { params(value: T.untyped, target: String, offset: Integer).returns(Integer) }
      def encode_into(value, target, offset)
        bytes = encode(value)
        target.b
        # Ensure target is long enough
        target << ("\x00".b * [0, offset + bytes.bytesize - target.bytesize].max)
        target[offset, bytes.bytesize] = bytes
        bytes.bytesize
      end
    end
  end
end
