defmodule BloomList.Test.WhiteList do
  @moduledoc false

  use BloomList

  def start_link() do
    BloomList.start_link(__MODULE__,
      name: __MODULE__,
      bloom_options: [capacity: 2000_000, error: 0.3]
    )
  end

  def member?(key) do
    BloomList.member?(__MODULE__, key)
  end

  def sync_member?(key) do
    BloomList.sync_member?(__MODULE__, key)
  end

  # callback
  def init_bloom_data() do
    data_list = for i <- 1..1000_000, do: i
    {data_list, nil}
  end

  # callback
  defdelegate handle_reinit_bloom_data, to: __MODULE__, as: :init_bloom_data

  # __end_of_module__
end
