# typed: strict
# frozen_string_literal: true

require 'set'

# Codec system — mirrors @solana/codecs.
# Provides Encoder, Decoder, and Codec classes plus helpers for numbers,
# strings, and composite data structures.
require_relative 'codecs/bytes'
require_relative 'codecs/encoder'
require_relative 'codecs/decoder'
require_relative 'codecs/codec'
require_relative 'codecs/numbers'
require_relative 'codecs/strings'
require_relative 'codecs/data_structures'

module Solana::Ruby::Kit
  module Codecs
    # Makes the whole helper surface available as Codecs.u8_codec etc. This
    # relies on each module using `extend self` rather than `module_function`
    # - see the note in numbers.rb for why the distinction matters here.
    extend Numbers
    extend Strings
    extend DataStructures
    extend Bytes
  end
end
