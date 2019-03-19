defmodule BloomListTest do
  use ExUnit.Case

  alias BloomList.Test.BlackList
  alias BloomList.Test.WhiteList

  test "test blacklist" do
    {:ok, _} = BlackList.start_link()
    assert BlackList.member?(1)
    assert not BlackList.member?(6)
    :ok = BlackList.add(6)
    assert BlackList.member?(6)
    :ok = BlackList.delete(6)
    assert not BlackList.member?(6)
    :ok = BlackList.reinit()
    assert not BlackList.member?(1)
    :ok = BlackList.add_list([8, 9])
  end

  test "test whitelist" do
    {:ok, _} = WhiteList.start_link()

    for i <- 1..1000 do
      assert WhiteList.member?(i)
    end

    assert not WhiteList.member?(:a)
    assert not WhiteList.sync_member?(:a)
  end
end
