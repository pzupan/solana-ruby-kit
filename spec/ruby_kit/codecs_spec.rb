# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::Codecs do
  # codecs.rb extends Numbers, Strings, DataStructures and Bytes so the whole
  # helper surface is reachable as `Codecs.u32_codec` etc.
  #
  # That intent was silently defeated for a long time: those modules used
  # `module_function`, which marks their instance methods private, so extending
  # them installed PRIVATE singleton methods on Codecs. Every helper raised
  # NoMethodError for callers, and the kit itself worked around it internally by
  # reaching for `Numbers.u32_codec` directly.
  #
  # These specs pin the public contract so a return to `module_function` fails
  # here rather than in downstream code.
  HELPER_MODULES = [
    RubyKit::Codecs::Numbers,
    RubyKit::Codecs::Strings,
    RubyKit::Codecs::DataStructures,
    RubyKit::Codecs::Bytes
  ].freeze

  def helper_names(mod)
    mod.instance_methods(false) + mod.private_instance_methods(false)
  end

  it 'exposes every helper as a public module method on Codecs' do
    private_helpers = HELPER_MODULES.flat_map { |mod| helper_names(mod) }
                                    .uniq
                                    .reject { |name| described_class.respond_to?(name) }

    expect(private_helpers).to be_empty
  end

  it 'keeps the helpers callable on their defining module too' do
    HELPER_MODULES.each do |mod|
      expect(mod).to respond_to(*helper_names(mod))
    end
  end

  it 'round-trips through the Codecs-level entry point' do
    codec = described_class.u32_codec(endian: :little)

    expect(codec.encode(1234).bytes).to eq([210, 4, 0, 0])
    expect(codec.decode(codec.encode(1234)).first).to eq(1234)
  end

  it 'reaches string and byte helpers, not just numbers' do
    expect(described_class.utf8_codec.encode('hi').bytes).to eq([104, 105])
    expect(described_class).to respond_to(:base58_codec, :bytes_codec, :struct_codec)
  end
end
