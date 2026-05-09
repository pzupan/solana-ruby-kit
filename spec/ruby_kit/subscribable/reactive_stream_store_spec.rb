# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Solana::Ruby::Kit::Subscribable do
  include described_class

  let(:publisher) { Solana::Ruby::Kit::Subscribable::DataPublisher.new }

  describe 'ReactiveState' do
    subject(:state) { Solana::Ruby::Kit::Subscribable::ReactiveState.new(status: 'loaded', data: 42) }

    it 'exposes status, data, error' do
      expect(state.status).to eq('loaded')
      expect(state.data).to eq(42)
      expect(state.error).to be_nil
    end

    it 'is frozen' do
      expect(state).to be_frozen
    end

    it 'REACTIVE_LOADING_STATE starts in loading' do
      ls = Solana::Ruby::Kit::Subscribable::REACTIVE_LOADING_STATE
      expect(ls.status).to eq('loading')
      expect(ls.data).to be_nil
    end
  end

  describe 'create_reactive_store_from_data_publisher' do
    it 'starts in loading state' do
      store = create_reactive_store_from_data_publisher(publisher, data_channel: :data, error_channel: :error)
      expect(store.get_unified_state.status).to eq('loading')
    end

    it 'transitions to loaded when data arrives' do
      store = create_reactive_store_from_data_publisher(publisher, data_channel: :data, error_channel: :error)
      publisher.publish(:data, 'hello')
      expect(store.get_unified_state.status).to eq('loaded')
      expect(store.get_unified_state.data).to eq('hello')
    end

    it 'notifies subscribers on state change' do
      store = create_reactive_store_from_data_publisher(publisher, data_channel: :data, error_channel: :error)
      calls = []
      store.subscribe { calls << store.get_unified_state.data }
      publisher.publish(:data, 1)
      publisher.publish(:data, 2)
      expect(calls).to eq([1, 2])
    end

    it 'returns an unsubscribe lambda' do
      store = create_reactive_store_from_data_publisher(publisher, data_channel: :data, error_channel: :error)
      calls = []
      unsub = store.subscribe { calls << 1 }
      publisher.publish(:data, 'a')
      unsub.call
      publisher.publish(:data, 'b')
      expect(calls.size).to eq(1)
    end

    it 'transitions to error on error channel message, preserving last data' do
      store = create_reactive_store_from_data_publisher(publisher, data_channel: :data, error_channel: :error)
      publisher.publish(:data, 99)
      err = RuntimeError.new('boom')
      publisher.publish(:error, err)
      state = store.get_unified_state
      expect(state.status).to eq('error')
      expect(state.data).to eq(99)
      expect(state.error).to eq(err)
    end

    it 'retry raises RETRY_NOT_SUPPORTED' do
      store = create_reactive_store_from_data_publisher(publisher, data_channel: :data, error_channel: :error)
      expect { store.retry }.to raise_error(Solana::Ruby::Kit::SolanaError, /retry/i)
    end

    it 'ReactiveStore is an alias for ReactiveStreamStore' do
      expect(Solana::Ruby::Kit::Subscribable::ReactiveStore)
        .to eq(Solana::Ruby::Kit::Subscribable::ReactiveStreamStore)
    end
  end

  describe 'create_reactive_store_from_data_publisher_factory' do
    it 'starts in loading and loads on data' do
      store = create_reactive_store_from_data_publisher_factory(
        data_channel: :data, error_channel: :error
      ) { publisher }
      publisher.publish(:data, 'val')
      expect(store.get_unified_state.status).to eq('loaded')
      expect(store.get_unified_state.data).to eq('val')
    end

    it 'supports retry after error' do
      pub2 = Solana::Ruby::Kit::Subscribable::DataPublisher.new
      calls = 0
      publishers = [publisher, pub2]
      store = create_reactive_store_from_data_publisher_factory(
        data_channel: :data, error_channel: :error
      ) { publishers[calls].tap { calls += 1 } }

      publisher.publish(:error, RuntimeError.new('fail'))
      expect(store.get_unified_state.status).to eq('error')

      store.retry
      pub2.publish(:data, 'recovered')
      expect(store.get_unified_state.status).to eq('loaded')
      expect(store.get_unified_state.data).to eq('recovered')
    end
  end
end
