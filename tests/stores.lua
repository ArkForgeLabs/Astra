local stores = require("stores")
require("test")

---@param test Test
return function(test)
  local describe, it, expect = test.describe, test.it, test.expect

  -------------------------------------------------------------------------------
  -- Observable
  -------------------------------------------------------------------------------
  describe("Observable", function()
    it("creates observable with initial value", function()
      local obs = stores.observable(42)
      expect(obs.value).to.equal(42)
    end)

    it("creates observable with nil initial value", function()
      local obs = stores.observable(nil)
      expect(obs.value).to.equal(nil)
    end)

    it("creates observable with table initial value", function()
      local tbl = { a = 1 }
      local obs = stores.observable(tbl)
      expect(obs.value).to.equal(tbl)
    end)

    it("has expected methods", function()
      local obs = stores.observable(0)
      expect(obs.subscribe).to.be.a("function")
      expect(obs.unsubscribe).to.be.a("function")
      expect(obs.publish).to.be.a("function")
    end)

    it("subscribe adds observer to list", function()
      local obs = stores.observable(0)
      local fn = function() end
      obs:subscribe(fn)
      expect(#obs.observers).to.equal(1)
    end)

    it("multiple subscribe adds multiple observers", function()
      local obs = stores.observable(0)
      obs:subscribe(function() end)
      obs:subscribe(function() end)
      obs:subscribe(function() end)
      expect(#obs.observers).to.equal(3)
    end)

    it("observer is called on publish", function()
      local obs = stores.observable(0)
      local called = false
      obs:subscribe(function()
        called = true
      end)
      obs:publish("test")
      expect(called).to.equal(true)
    end)

    it("observer receives published data", function()
      local obs = stores.observable(0)
      local received
      obs:subscribe(function(data)
        received = data
      end)
      obs:publish("hello")
      expect(received).to.equal("hello")
    end)

    it("multiple observers are all called", function()
      local obs = stores.observable(0)
      local count = 0
      obs:subscribe(function()
        count = count + 1
      end)
      obs:subscribe(function()
        count = count + 1
      end)
      obs:publish("data")
      expect(count).to.equal(2)
    end)

    it("unsubscribe removes observer", function()
      local obs = stores.observable(0)
      local fn = function()
        error("should not be called")
      end
      obs:subscribe(fn)
      obs:unsubscribe(fn)
      expect(#obs.observers).to.equal(0)
    end)

    it("unsubscribed observer is not called on publish", function()
      local obs = stores.observable(0)
      local called = false
      local fn = function()
        called = true
      end
      obs:subscribe(fn)
      obs:unsubscribe(fn)
      obs:publish("data")
      expect(called).to.equal(false)
    end)

    it("unsubscribe nonexistent observer is safe", function()
      local obs = stores.observable(0)
      obs:unsubscribe(function() end)
      -- no error
    end)

    it("publish with no observers is safe", function()
      local obs = stores.observable(0)
      obs:publish("data")
      -- no error
    end)

    it("publish does not modify value", function()
      local obs = stores.observable(42)
      obs:publish(99)
      expect(obs.value).to.equal(42)
    end)
  end)

  -------------------------------------------------------------------------------
  -- PubSub
  -------------------------------------------------------------------------------
  describe("PubSub", function()
    it("pubsub module exists with expected methods", function()
      expect(stores.pubsub).to.be.a("table")
      expect(stores.pubsub.subscribe).to.be.a("function")
      expect(stores.pubsub.unsubscribe).to.be.a("function")
      expect(stores.pubsub.publish).to.be.a("function")
    end)

    it("subscribe adds callback for topic", function()
      local called = false
      stores.pubsub.subscribe("ps_test1", function()
        called = true
      end)
      stores.pubsub.publish("ps_test1", "data")
      expect(called).to.equal(true)
    end)

    it("subscriber receives data and topic", function()
      local recv_data, recv_topic
      stores.pubsub.subscribe("ps_test2", function(data, topic)
        recv_data = data
        recv_topic = topic
      end)
      stores.pubsub.publish("ps_test2", "hello")
      expect(recv_data).to.equal("hello")
      expect(recv_topic).to.equal("ps_test2")
    end)

    it("multiple subscribers on same topic", function()
      local count = 0
      stores.pubsub.subscribe("ps_test3", function()
        count = count + 1
      end)
      stores.pubsub.subscribe("ps_test3", function()
        count = count + 1
      end)
      stores.pubsub.publish("ps_test3", "data")
      expect(count).to.equal(2)
    end)

    it("different topics are isolated", function()
      local called = false
      stores.pubsub.subscribe("ps_test4", function()
        called = true
      end)
      stores.pubsub.publish("ps_test5", "data")
      expect(called).to.equal(false)
    end)

    it("unsubscribe removes specific callback", function()
      local called = false
      local fn = function()
        called = true
      end
      stores.pubsub.subscribe("ps_test6", fn)
      stores.pubsub.unsubscribe("ps_test6", fn)
      stores.pubsub.publish("ps_test6", "data")
      expect(called).to.equal(false)
    end)

    it("unsubscribe without callback removes last subscriber", function()
      local fn1, fn2
      local count = 0

      fn1 = function()
        count = count + 1
      end
      fn2 = function()
        count = count + 1
      end

      stores.pubsub.subscribe("ps_test7", fn1)
      stores.pubsub.subscribe("ps_test7", fn2)
      stores.pubsub.unsubscribe("ps_test7") -- removes fn2 (last)
      stores.pubsub.publish("ps_test7", "data")
      expect(count).to.equal(1)
    end)

    it("unsubscribe nonexistent topic is safe", function()
      stores.pubsub.unsubscribe("ps_nonexistent", function() end)
      -- no error
    end)

    it("publish with no subscribers is safe", function()
      stores.pubsub.publish("ps_empty", "data")
      -- no error
    end)

    it("publish iterates snapshot when subscriber modifies list", function()
      local call_order = {}
      local fn_a, fn_b

      fn_a = function()
        table.insert(call_order, "a")
        stores.pubsub.unsubscribe("ps_snap", fn_b)
      end
      fn_b = function()
        table.insert(call_order, "b")
      end

      stores.pubsub.subscribe("ps_snap", fn_a)
      stores.pubsub.subscribe("ps_snap", fn_b)
      stores.pubsub.publish("ps_snap", "data")
      -- Both should be called even though fn_a removed fn_b
      expect(#call_order).to.equal(2)
      expect(call_order[1]).to.equal("a")
      expect(call_order[2]).to.equal("b")
    end)
  end)
end
