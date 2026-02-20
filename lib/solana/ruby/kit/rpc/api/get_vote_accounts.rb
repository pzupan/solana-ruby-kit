# typed: strict
# frozen_string_literal: true

module Solana::Ruby::Kit
  module Rpc
    module Api
      # Vote account info struct.
      VoteAccountInfo = T.let(
        Struct.new(
          :vote_pubkey,
          :node_pubkey,
          :activated_stake,
          :epoch_vote_account,
          :commission,
          :last_vote,
          :epoch_credits,
          :root_slot,
          keyword_init: true
        ),
        T.untyped
      )

      # Fetch current and delinquent vote accounts.
      # Returns { current: [], delinquent: [] }.
      module GetVoteAccounts
        extend T::Sig

        sig do
          params(
            commitment:  T.nilable(Symbol),
            vote_pubkey: T.nilable(String)
          ).returns(T::Hash[Symbol, T::Array[T.untyped]])
        end
        def get_vote_accounts(commitment: nil, vote_pubkey: nil)
          config = {}
          config['commitment']  = commitment.to_s  if commitment
          config['votePubkey']  = vote_pubkey       if vote_pubkey

          raw = transport.request('getVoteAccounts', config.empty? ? [] : [config])

          parse_vote = Kernel.lambda do |v|
            VoteAccountInfo.new(
              vote_pubkey:        v['votePubkey'],
              node_pubkey:        v['nodePubkey'],
              activated_stake:    Kernel.Integer(v['activatedStake']),
              epoch_vote_account: v['epochVoteAccount'],
              commission:         Kernel.Integer(v['commission']),
              last_vote:          Kernel.Integer(v['lastVote']),
              epoch_credits:      v['epochCredits'],
              root_slot:          v['rootSlot'] ? Kernel.Integer(v['rootSlot']) : nil
            )
          end

          {
            current:    Kernel.Array(raw['current']).map(&parse_vote),
            delinquent: Kernel.Array(raw['delinquent']).map(&parse_vote)
          }
        end
      end
    end
  end
end
