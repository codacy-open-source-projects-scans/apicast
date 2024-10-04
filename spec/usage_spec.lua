local Usage = require('apicast.usage')

describe('usage', function()
  describe('.add', function()
    describe('when the metric is already present in the usage', function()
      it('adds the given value to the existing one', function()
        local usage = Usage.new()

        usage:add('hits', 1)
        assert.same({ hits = 1 }, usage.deltas )

        usage:add('hits', 1)
        assert.same({ hits = 2 }, usage.deltas)
      end)
    end)

    describe('when the metric is not in the usage', function()
      it('adds it with the given value', function()
        local usage = Usage.new()
        usage:add('hits', 1)

        assert.same({ hits = 1 }, usage.deltas)
      end)
    end)
  end)

  describe('.merge', function()
    describe('when a metric appears in both usages', function()
      it('mutates self adding the deltas', function()
        local a_usage = Usage.new()
        a_usage:add('a', 1)
        a_usage:add('b', 1)

        local another_usage = Usage.new()
        another_usage:add('a', 2)
        another_usage:add('b', 2)

        a_usage:merge(another_usage)

        assert.same({ a = 3, b = 3 }, a_usage.deltas)
      end)
    end)

    describe('when a metric of the given usage is not in self', function()
      it('adds the metric in self', function()
        local a_usage = Usage.new()
        a_usage:add('a', 1)

        local another_usage = Usage.new()
        another_usage:add('b', 1)

        a_usage:merge(another_usage)

        assert.same({ a = 1, b = 1 }, a_usage.deltas)
      end)
    end)

    describe('when the other usage does not contain any deltas', function()
      it('leaves self unchanged', function()
        local a_usage = Usage.new()
        a_usage:add('a', 1)

        a_usage:merge(Usage.new())

        assert.same({ a = 1 }, a_usage.deltas)
      end)
    end)

    describe("when the given usage is negative", function()

      local usage = Usage.new()

      before_each(function()
        usage = Usage.new()
        usage:add("a", 3)
      end)

      it("keeps metrics if are positive", function()
        local a_usage = Usage.new()
        a_usage:add("a", -2)

        usage:merge(a_usage)

        assert.same({ a = 1 }, usage.deltas)
        assert.same({ "a" }, usage.metrics)
      end)

      it("Delete metric if value is 0", function()
        local a_usage = Usage.new()
        a_usage:add("a", -3)

        usage:merge(a_usage)

        assert.same({  }, usage.deltas)
        assert.same({ }, usage.metrics)
      end)

      it("Delete metric if value is equal or bellow 0", function()
        local a_usage = Usage.new()
        a_usage:add("a", -4)

        usage:merge(a_usage)

        assert.same({  }, usage.deltas)
        assert.same({ }, usage.metrics)
      end)

      it("keep metrics value if one is bellow 0", function()
        usage:add("b", 10)

        local a_usage = Usage.new()
        a_usage:add("a", -4)

        usage:merge(a_usage)

        assert.same({ b = 10 }, usage.deltas)
        assert.same({ "b" }, usage.metrics)
      end)

    end)
  end)

  describe('.metrics', function()
    it('returns a table without duplicates with all the metrics that have a delta', function()
      local usage = Usage.new()
      usage:add('hits', 1)
      usage:add('hits', 1) -- try adding a metric that already exists
      usage:add('some_metric', 1)

      -- Try merging with a usage with the same metrics.
      local another_usage = Usage.new()
      another_usage:add('hits', 1)
      another_usage:add('some_metric', 1)
      usage:merge(another_usage)

      local metrics = usage.metrics

      -- The method does not guarantee any order in the result
      assert.is_true((metrics[1] == 'hits' and metrics[2] == 'some_metric') or
          (metrics[1] == 'some_metric' and metrics[2] == 'hits'))
    end)
  end)

  describe(".format", function()
    it("returns valid response with data", function()
      local usage = Usage.new()
      usage:add('hits', 2)
      usage:add('some_metric', 1)
      local result = {
        ["usage[hits]"] = 2,
        ["usage[some_metric]"] = 1,
      }
      assert.are.same(usage:format(), result)
    end)

    it("returns empty if no metrics added", function()
      local usage = Usage.new()
      local result = {}
      assert.are.same(usage:format(), result)
    end)

    it("returns 0 values correctly", function()
      local usage = Usage.new()
      usage:add('hits', 0)
      local result = {
        ["usage[hits]"] = 0,
      }
      assert.are.same(usage:format(), result)
    end)
  end)

  describe("encode format", function()
    it("works with a single metric", function()
      local usage = Usage.new()
      usage:add('hits', 0)
      assert.are.same(usage:encoded_format(), "usage%5Bhits%5D=0")
    end)

    it("with multiple metrics return the same", function()
      local usage = Usage.new()
      usage:add('a', 1)
      usage:add('c', 3)
      usage:add('b', 2)
      assert.are.same(usage:encoded_format(), "usage%5Ba%5D=1&usage%5Bb%5D=2&usage%5Bc%5D=3")
      -- Multiple cases just in case
      local usage = Usage.new()
      usage:add('c', 3)
      usage:add('a', 1)
      usage:add('b', 2)
      assert.are.same(usage:encoded_format(), "usage%5Ba%5D=1&usage%5Bb%5D=2&usage%5Bc%5D=3")

    end)

    it("integer metrics", function()
      local usage = Usage.new()
      usage:add(1, 10)
      assert.are.same(usage:encoded_format(), "usage%5B1%5D=10")
    end)

    it("no metrics", function()
      local usage = Usage.new()
      assert.are.same(usage:encoded_format(), "")
    end)

  end)

  describe("get_max_delta", function()
    it("When no metrics", function()
      local usage = Usage.new()

      local result = usage:get_max_delta()

      assert.Same(result, 0)
    end)

    it("when multiple metrics", function()

      local usage = Usage.new()
      usage:add("foo", 10)
      usage:add("bar", 20)

      local result = usage:get_max_delta()

      assert.Same(result, 20)
    end)

  end)

end)
