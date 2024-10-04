local loader = require 'apicast.configuration_loader.file'

describe('Configuration File loader', function()
  describe('.call', function()
    it('ignores empty path', function()
      assert.same({nil, 'invalid or missing path'}, { loader.call() })
      assert.same({nil, 'invalid or missing path'}, { loader.call('') })
    end)

    it('reads a file', function()
      assert.truthy(loader.call('fixtures/config.json'))
    end)

    it('reads absolute path', function()
      local pl_path = require('pl.path')
      local _, path = loader.call('fixtures/config.json')

      assert.match(pl_path.currentdir(), path, nil, true)
    end)
  end)
end)
