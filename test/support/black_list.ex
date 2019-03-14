defmodule BloomList.Test.BlackList do
  @moduledoc false

  use BloomList

  def start_link() do
    BloomList.start_link(__MODULE__,
      name: __MODULE__,
      bloom_options: [capacity: 2000, error: 0.7]
    )
  end

  def reinit do
    BloomList.reinit_bloom_data(__MODULE__)
  end

  def add(key) do
    BloomList.add(__MODULE__, key)
  end

  def delete(key) do
    BloomList.delete(__MODULE__, key)
  end

  def member?(key) do
    BloomList.member?(__MODULE__, key)
  end

  # callback
  def init_bloom_data() do
    data_list = [1, 2, 3, 4, 5]
    {data_list, %{data_list: data_list}}
  end

  # callback
  def handle_reinit_bloom_data() do
    data_list = [2, 3, 4, 5, 6, 7]
    {data_list, %{data_list: data_list}}
  end

  # callback
  def handle_maybe_exist(key, %{data_list: data_list}) do
    Enum.member?(data_list, key)
  end

  # callback
  def handle_delete(key, %{data_list: data_list} = state) do
    %{state | data_list: List.delete(data_list, key)}
  end

  # callback
  def handle_add(key, %{data_list: data_list} = state) do
    %{state | data_list: [key | data_list]}
  end

  # __end_of_module__
end
