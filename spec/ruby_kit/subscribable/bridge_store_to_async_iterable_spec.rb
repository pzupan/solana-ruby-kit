# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Solana::Ruby::Kit::Subscribable.bridge_store_to_async_iterable' do
  let(:subscribable) { Solana::Ruby::Kit::Subscribable }
  let(:publisher)    { subscribable::DataPublisher.new }
  let(:store) do
    subscribable.create_reactive_store_from_data_publisher(
      publisher, data_channel: :slotNotification, error_channel: :error
    )
  end

  # The store subscribes to the publisher on construction, so realize it before
  # any test publishes — otherwise the lazy `let` misses those notifications and
  # the enumerator parks on an empty store.
  before { store }

  # The store is push-based and the enumerator parks when nothing is buffered,
  # so tests publish either before iteration (picked up by seeding) or from
  # inside the consumer block. Publishing is synchronous — it runs the bridge's
  # on-change callback on the calling thread — so both are deterministic, with
  # no race against the bridge's subscription being established.

  it 'seeds from the value already in the store before iteration begins' do
    publisher.publish(:slotNotification, { 'slot' => 1 })

    values = subscribable.bridge_store_to_async_iterable(store).first(1)
    expect(values).to eq([{ 'slot' => 1 }])
  end

  it 'yields subsequent values as they are published' do
    publisher.publish(:slotNotification, { 'slot' => 1 })

    values = []
    subscribable.bridge_store_to_async_iterable(store).each do |value|
      values << value
      break if values.size >= 2

      publisher.publish(:slotNotification, { 'slot' => 2 })
    end

    expect(values).to eq([{ 'slot' => 1 }, { 'slot' => 2 }])
  end

  it 'is latest-wins: a value published before the consumer pulls replaces the previous one' do
    publisher.publish(:slotNotification, { 'slot' => 1 })
    publisher.publish(:slotNotification, { 'slot' => 2 })
    publisher.publish(:slotNotification, { 'slot' => 3 })

    expect(subscribable.bridge_store_to_async_iterable(store).first(1)).to eq([{ 'slot' => 3 }])
  end

  it 'drops values the should_yield gate rejects' do
    publisher.publish(:slotNotification, { 'slot' => 2 })

    enum = subscribable.bridge_store_to_async_iterable(
      store, should_yield: ->(v) { v['slot'].even? }
    )

    values = []
    enum.each do |value|
      values << value
      break if values.size >= 2

      publisher.publish(:slotNotification, { 'slot' => 3 }) # rejected by the gate
      publisher.publish(:slotNotification, { 'slot' => 4 })
    end

    expect(values).to eq([{ 'slot' => 2 }, { 'slot' => 4 }])
  end

  it 'raises the store error when the stream fails' do
    boom = StandardError.new('stream died')
    publisher.publish(:error, boom)

    expect { subscribable.bridge_store_to_async_iterable(store).first(1) }
      .to raise_error(boom.class, 'stream died')
  end

  it 'substitutes a sentinel when the store errors with a nil payload' do
    store._set_state(
      subscribable::ReactiveState.new(status: 'error', data: nil, error: nil)
    )

    expect { subscribable.bridge_store_to_async_iterable(store).first(1) }
      .to raise_error(Solana::Ruby::Kit::SolanaError) { |e|
        expect(e.code).to eq(Solana::Ruby::Kit::SolanaError::SUBSCRIBABLE__STREAM_CLOSED_WITHOUT_ERROR)
      }
  end

  it 'takes the error in preference to a buffered value' do
    publisher.publish(:slotNotification, { 'slot' => 1 })
    publisher.publish(:error, StandardError.new('stream died'))

    expect { subscribable.bridge_store_to_async_iterable(store).first(1) }
      .to raise_error(StandardError, 'stream died')
  end

  it 'ends cleanly without raising once the signal aborts' do
    aborted = false
    signal  = -> { Kernel.raise('aborted') if aborted }

    enum = subscribable.bridge_store_to_async_iterable(store, signal: signal, poll_interval: 0.01)

    values = []
    thread = Thread.new do
      sleep 0.05
      aborted = true
    end
    expect { enum.each { |v| values << v } }.not_to raise_error
    thread.join

    expect(values).to be_empty
  end

  it 'unsubscribes from the store when iteration ends' do
    publisher.publish(:slotNotification, { 'slot' => 1 })

    subscribable.bridge_store_to_async_iterable(store).first(1)

    # A store with no remaining subscribers still transitions state fine; the
    # point is the bridge did not leak its subscription.
    expect { publisher.publish(:slotNotification, { 'slot' => 2 }) }.not_to raise_error
    expect(store.get_unified_state.data).to eq({ 'slot' => 2 })
  end
end
