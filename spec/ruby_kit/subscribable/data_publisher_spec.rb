# typed: ignore
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyKit::Subscribable::DataPublisher do
  subject(:publisher) { described_class.new }

  describe '#on / #publish' do
    it 'delivers data to a subscriber' do
      received = []
      publisher.on(:test) { |d| received << d }
      publisher.publish(:test, 'hello')
      expect(received).to eq(['hello'])
    end

    it 'allows multiple subscribers on the same channel' do
      log = []
      publisher.on(:ch) { |d| log << "A:#{d}" }
      publisher.on(:ch) { |d| log << "B:#{d}" }
      publisher.publish(:ch, 1)
      expect(log).to contain_exactly('A:1', 'B:1')
    end

    it 'returns an unsubscribe lambda that stops delivery' do
      log = []
      unsub = publisher.on(:ch) { |d| log << d }
      publisher.publish(:ch, 1)
      unsub.call
      publisher.publish(:ch, 2)
      expect(log).to eq([1])
    end

    it 'removes subscriber whose signal fires' do
      received = []
      fired    = false
      signal   = lambda { raise 'aborted' if fired }
      publisher.on(:ch, signal: signal) { |d| received << d }

      publisher.publish(:ch, 'before')
      fired = true
      publisher.publish(:ch, 'after')

      expect(received).to eq(['before'])
    end
  end

  describe '#close' do
    it 'emits on :close channel then clears all subscribers' do
      close_log = []
      publisher.on(RubyKit::Subscribable::DataPublisher::CLOSE_CHANNEL) { |_| close_log << :closed }
      publisher.close
      publisher.publish(:test, 'noop')
      expect(close_log).to eq([:closed])
    end
  end
end
