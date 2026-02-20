# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::Codecs::Strings do
  include RubyKit::Codecs::Strings
  include RubyKit::Codecs::Numbers

  describe 'utf8_codec (variable)' do
    let(:codec) { utf8_codec }

    it 'encodes a string to its UTF-8 bytes' do
      expect(codec.encode('hello').bytes).to eq([104, 101, 108, 108, 111])
    end

    it 'round-trips a UTF-8 string' do
      val, = codec.decode(codec.encode('héllo'))
      expect(val).to eq('héllo')
    end
  end

  describe 'utf8_codec (fixed size)' do
    let(:codec) { utf8_codec(size: 10) }

    it 'pads short strings' do
      expect(codec.encode('hi').bytesize).to eq(10)
    end
  end

  describe 'hex_codec' do
    let(:codec) { hex_codec }

    it 'encodes a hex string to bytes' do
      expect(codec.encode('ff00').bytes).to eq([0xFF, 0x00])
    end

    it 'decodes bytes to hex string' do
      val, = codec.decode("\xFF\x00".b)
      expect(val).to eq('ff00')
    end
  end

  describe 'bytes_codec' do
    let(:codec) { bytes_codec(4) }

    it 'passes through exactly 4 bytes' do
      raw = "\x01\x02\x03\x04".b
      val, n = codec.decode(codec.encode(raw))
      expect(val).to eq(raw)
      expect(n).to eq(4)
    end

    it 'raises on wrong size' do
      expect { codec.encode("\x01\x02".b) }.to raise_error(ArgumentError)
    end
  end

  describe 'bit_array_codec' do
    let(:codec) { bit_array_codec(1) }

    it 'encodes bits into a byte' do
      bits  = [true, false, true, false, false, false, false, false]
      bytes = codec.encode(bits)
      expect(bytes.bytes.first).to eq(0b00000101)
    end

    it 'decodes a byte into bits' do
      bits, = codec.decode([0b00000101].pack('C'))
      expect(bits.first(3)).to eq([true, false, true])
    end
  end
end
