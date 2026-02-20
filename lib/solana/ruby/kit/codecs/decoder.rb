# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Codecs
    # Mirrors the TypeScript Decoder<T> interface from @solana/codecs-core.
    #
    # A Decoder knows how to turn binary bytes into a Ruby value.
    # Fixed-size decoders advertise their byte length via +fixed_size+;
    # variable-size decoders leave it nil.
    #
    # The inner block receives +(bytes, offset)+ and must return
    # +[value, bytes_consumed]+.
    class Decoder
      extend T::Sig

      sig { returns(T.nilable(Integer)) }
      attr_reader :fixed_size

      sig do
        params(
          fixed_size: T.nilable(Integer),
          block:      T.proc.params(bytes: String, offset: Integer)
                             .returns([T.untyped, Integer])
        ).void
      end
      def initialize(fixed_size: nil, &block)
        @fixed_size = fixed_size
        @fn = T.let(
          block,
          T.proc.params(bytes: String, offset: Integer).returns([T.untyped, Integer])
        )
      end

      # Decode from +bytes+ starting at +offset+.
      # Returns +[value, bytes_consumed]+.
      sig { params(bytes: String, offset: Integer).returns([T.untyped, Integer]) }
      def decode(bytes, offset: 0)
        @fn.call(bytes.b, offset)
      end
    end
  end
end
