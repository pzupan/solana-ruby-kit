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
    # Make number helpers directly available as Codecs.u8_codec etc.
    extend Numbers
    extend Strings
    extend DataStructures
    extend Bytes
  end
end
