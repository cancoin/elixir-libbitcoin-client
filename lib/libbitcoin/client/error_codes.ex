defmodule Libbitcoin.Client.ErrorCode do

  @error_codes [
    :success,

    # network errors
    :service_stopped,
    :operation_failed,

    # blockchain errors
    :not_found,
    :duplicate,
    :unspent_output,
    :unsupported_script_pattern,

    # network errors (more)
    :resolve_failed,
    :network_unreachable,
    :address_in_use,
    :listen_failed,
    :accept_failed,
    :bad_stream,
    :channel_timeout,

    # transaction pool
    :blockchain_reorganized,
    :pool_filled,

    # validate tx
    :coinbase_transaction,
    :is_not_standard,
    :double_spend,
    :input_not_found,

    # check_transaction()
    :empty_transaction,
    :output_value_overflow,
    :invalid_coinbase_script_size,
    :previous_output_null,

    # validate block
    :previous_block_invalid,

    # check_block()
    :size_limits,
    :proof_of_work,
    :futuristic_timestamp,
    :first_not_coinbase,
    :extra_coinbases,
    :too_many_sigs,
    :merkle_mismatch,

    # accept_block()
    :incorrect_proof_of_work,
    :timestamp_too_early,
    :non_final_transaction,
    :checkpoints_failed,
    :old_version_block,
    :coinbase_height_mismatch,

    # connect_block()
    :duplicate_or_spent,
    :validate_inputs_failed,
    :fees_out_of_range,
    :coinbase_too_large,

    # file system errors
    :file_system,

    # unknown errors
    :unknown,

    # network errors (more)
    :address_blocked,
    :channel_stopped
  ]

  defmacro __using__(_opts) do
    quote do
      import Libbitcoin.Client.ErrorCode
      for {reason, index} <- Enum.with_index(unquote(@error_codes)) do
         Module.put_attribute(__MODULE__, reason, index)
         def error_code(index) do
           Enum.at(unquote(@error_codes), index)
         end
         def error_mesesage(index) do
           error_code(index) |> error_message
         end
      end
    end
  end

  def error_message(:success), do:
    "success"

  # network errors
  def error_message(:service_stopped), do:
    "service is stopped"
  def error_message(:operation_failed), do:
    "operation failed"

  # blockchain errors
  def error_message(:not_found), do:
    "object does not exist"
  def error_message(:duplicate), do:
    "matching previous object found"
  def error_message(:unspent_output), do:
    "unspent output"
  def error_message(:unsupported_script_pattern), do:
    "unsupport script pattern"

  # network errors (more)
  def error_message(:resolve_failed), do:
    "resolving hostname failed"
  def error_message(:network_unreachable), do:
    "unable to reach remote host"
  def error_message(:address_in_use), do:
    "address already in use"
  def error_message(:listen_failed), do:
    "incoming connection failed"
  def error_message(:accept_failed), do:
    "connection acceptance failed"
  def error_message(:bad_stream), do:
    "bad data stream"
  def error_message(:channel_timeout), do:
    "connection timed out"

  # transaction pool
  def error_message(:blockchain_reorganized), do:
    "transactions invalidated by blockchain reorganization"
  def error_message(:pool_filled), do:
    "forced removal of old transaction from pool overflow"

  # validate tx
  def error_message(:coinbase_transaction), do:
    "coinbase transaction disallowed in memory pool"
  def error_message(:is_not_standard), do:
    "transaction is not standard"
  def error_message(:double_spend), do:
    "double spend of input"
  def error_message(:input_not_found), do:
    "spent input not found"

  # check_transaction()
  def error_message(:empty_transaction), do:
    "transaction inputs or outputs are empty"
  def error_message(:output_value_overflow), do:
    "output value outside valid range"
  def error_message(:invalid_coinbase_script_size), do:
    "coinbase script is too small or large"
  def error_message(:previous_output_null), do:
    "non-coinbase transaction has input with null previous output"

  # validate block
  def error_message(:previous_block_invalid), do:
    "previous block failed to validate"

  # check_block()
  def error_message(:size_limits), do:
    "size limits failed"
  def error_message(:proof_of_work), do:
    "proof of work failed"
  def error_message(:futuristic_timestamp), do:
    "timestamp too far in the future"
  def error_message(:first_not_coinbase), do:
    "first transaction is not a coinbase"
  def error_message(:extra_coinbases), do:
    "more than one coinbase"
  def error_message(:too_many_sigs), do:
    "too many script signatures"
  def error_message(:merkle_mismatch), do:
    "merkle root mismatch"

  # accept_block()
  def error_message(:incorrect_proof_of_work), do:
    "proof of work does not match bits field"
  def error_message(:timestamp_too_early), do:
    "block timestamp is too early"
  def error_message(:non_final_transaction), do:
    "block contains a non-final transaction"
  def error_message(:checkpoints_failed), do:
    "block hash rejected by checkpoint"
  def error_message(:old_version_block), do:
    "block version one rejected at current height"
  def error_message(:coinbase_height_mismatch), do:
    "block height mismatch in coinbase"

  # connect_block()
  def error_message(:duplicate_or_spent), do:
    "duplicate transaction with unspent outputs"
  def error_message(:validate_inputs_failed), do:
    "validation of inputs failed"
  def error_message(:fees_out_of_range), do:
    "fees are out of range"
  def error_message(:coinbase_too_large), do:
    "coinbase value is too large"

  # file system errors
  def error_message(:file_system), do:
    "file system error"

  # network errors
  def error_message(:address_blocked), do:
    "address is blocked by policy"
  def error_message(:channel_stopped), do:
    "channel is stopped"

  # unknown errors
  def error(_), do:
    "unknown error"

end
