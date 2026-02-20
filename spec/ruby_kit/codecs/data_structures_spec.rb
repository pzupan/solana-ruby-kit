# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::Codecs::DataStructures do
  include RubyKit::Codecs::DataStructures
  include RubyKit::Codecs::Numbers
  include RubyKit::Codecs::Strings

  describe 'struct_codec' do
    let(:codec) do
      struct_codec([
        [:name,  utf8_codec(size: 4)],
        [:value, u32_codec]
      ])
    end

    it 'round-trips a hash' do
      original = { name: 'abc', value: 42 }
      name_b   = 'abc'.b + "\x00".b
      value_b  = [42].pack('V')
      encoded  = name_b + value_b

      decoded, = codec.decode(codec.encode(original))
      expect(decoded[:value]).to eq(42)
    end
  end

  describe 'array_codec (prefixed)' do
    let(:codec) { array_codec(u8_codec) }

    it 'round-trips an array' do
      arr     = [1, 2, 3]
      decoded, = codec.decode(codec.encode(arr))
      expect(decoded).to eq(arr)
    end
  end

  describe 'array_codec (fixed size)' do
    let(:codec) { array_codec(u8_codec, size: 3) }

    it 'encodes without a length prefix' do
      expect(codec.encode([1, 2, 3]).bytesize).to eq(3)
    end
  end

  describe 'tuple_codec' do
    let(:codec) { tuple_codec([u8_codec, u16_codec]) }

    it 'round-trips a positional array' do
      decoded, = codec.decode(codec.encode([7, 300]))
      expect(decoded).to eq([7, 300])
    end
  end

  describe 'option_codec' do
    let(:codec) { option_codec(u32_codec) }

    it 'encodes None as a single 0x00 byte' do
      expect(codec.encode(RubyKit::Options.none)).to eq("\x00".b)
    end

    it 'round-trips Some(42)' do
      some    = RubyKit::Options::Some.new(42)
      decoded, = codec.decode(codec.encode(some))
      expect(decoded).to be_a(RubyKit::Options::Some)
      expect(decoded.value).to eq(42)
    end
  end
end
