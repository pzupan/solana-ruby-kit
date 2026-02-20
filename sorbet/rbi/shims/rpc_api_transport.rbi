# typed: true
# Shim: declare `transport` (and `_build_subscription`) on RPC mixin modules.
# These methods are provided by the including class (Rpc::Client /
# RpcSubscriptions::Client) at runtime, but Sorbet cannot infer them from
# the mixin pattern alone.

module Solana::Ruby::Kit::Rpc::Api::GetAccountInfo
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::Rpc::Api::GetBalance
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::Rpc::Api::GetBlockHeight
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::Rpc::Api::GetEpochInfo
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::Rpc::Api::GetLatestBlockhash
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::Rpc::Api::GetMinimumBalanceForRentExemption
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::Rpc::Api::GetMultipleAccounts
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::Rpc::Api::GetProgramAccounts
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::Rpc::Api::GetSignatureStatuses
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::Rpc::Api::GetSlot
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::Rpc::Api::GetTokenAccountBalance
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::Rpc::Api::GetTokenAccountsByOwner
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::Rpc::Api::GetTransaction
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::Rpc::Api::GetVoteAccounts
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::Rpc::Api::IsBlockhashValid
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::Rpc::Api::RequestAirdrop
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::Rpc::Api::SendTransaction
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::Rpc::Api::SimulateTransaction
  sig { returns(T.untyped) }
  def transport; end
end

module Solana::Ruby::Kit::RpcSubscriptions::Api::AccountNotifications
  sig { returns(T.untyped) }
  def transport; end

  sig { params(sub_id: T.untyped, unsub_method: String).returns(T.untyped) }
  def _build_subscription(sub_id, unsub_method); end
end

module Solana::Ruby::Kit::RpcSubscriptions::Api::LogsNotifications
  sig { returns(T.untyped) }
  def transport; end

  sig { params(sub_id: T.untyped, unsub_method: String).returns(T.untyped) }
  def _build_subscription(sub_id, unsub_method); end
end

module Solana::Ruby::Kit::RpcSubscriptions::Api::ProgramNotifications
  sig { returns(T.untyped) }
  def transport; end

  sig { params(sub_id: T.untyped, unsub_method: String).returns(T.untyped) }
  def _build_subscription(sub_id, unsub_method); end
end

module Solana::Ruby::Kit::RpcSubscriptions::Api::RootNotifications
  sig { returns(T.untyped) }
  def transport; end

  sig { params(sub_id: T.untyped, unsub_method: String).returns(T.untyped) }
  def _build_subscription(sub_id, unsub_method); end
end

module Solana::Ruby::Kit::RpcSubscriptions::Api::SignatureNotifications
  sig { returns(T.untyped) }
  def transport; end

  sig { params(sub_id: T.untyped, unsub_method: String).returns(T.untyped) }
  def _build_subscription(sub_id, unsub_method); end
end

module Solana::Ruby::Kit::RpcSubscriptions::Api::SlotNotifications
  sig { returns(T.untyped) }
  def transport; end

  sig { params(sub_id: T.untyped, unsub_method: String).returns(T.untyped) }
  def _build_subscription(sub_id, unsub_method); end
end
