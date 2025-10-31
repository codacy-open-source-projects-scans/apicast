local keys_helper = require 'apicast.policy.3scale_batcher.keys_helper'
local Usage = require 'apicast.usage'
local Transaction = require 'apicast.policy.3scale_batcher.transaction'
local JWT = require('resty.jwt')
local certs = require('fixtures.certs')

local access_token = setmetatable({
  header = { typ = 'JWT', alg = 'RS256', kid = 'somekid' },
  payload = {
    iss = 'http://example.com/issuer',
    sub = 'some',
    aud = 'one',
    exp = ngx.now() + 3600,
  },
}, { __tostring = function(jwt) return JWT:sign(certs.rsa_private_key, jwt) end })

describe('Keys Helper', function()
  describe('.key_for_cached_auth', function()
    it('returns a key with the expected format', function()
      local service_id = 's1'
      local credentials = { app_id = 'ai', app_key = 'ak' }
      local usage = Usage.new()
      usage:add('m1', 1)
      usage:add('m2', 2)
      local transaction = Transaction.new(service_id, credentials, usage)

      local key = keys_helper.key_for_cached_auth(transaction)
      assert.equals('service_id:s1,app_id:ai,app_key:ak,metrics:m1=1;m2=2', key)
    end)
  end)

  describe('.key_for_batched_report', function()
    it('returns a key with the expected format', function()
      local service_id = 's1'
      local credentials = { app_id = 'ai', app_key = 'ak' }
      local metric = 'm1'

      local key = keys_helper.key_for_batched_report(service_id, credentials, metric)
      assert.equals('service_id:s1,app_id:ai,app_key:ak,metric:m1', key)
    end)
  end)

  describe('.report_from_key_batched_report', function()
    it('returns a report given a key of a batched report with app ID and app key', function()
      local key = 'service_id:s1,app_id:ai,app_key:ak,metric:m1'

      local report = keys_helper.report_from_key_batched_report(key)
      assert.same({ service_id = 's1', app_id = 'ai', app_key = 'ak', metric = 'm1' }, report)

      -- app_key and app_id contain special chars
      key = 'service_id:s1,app_id:!#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~,app_key:!#$%&\'()*+,-.:;<=>?@[]^_`{|}~,metric:m1'
      report = keys_helper.report_from_key_batched_report(key)
      assert.same({ service_id = 's1', app_id = '!#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~', app_key = '!#$%&\'()*+,-.:;<=>?@[]^_`{|}~', metric = 'm1' }, report)
    end)

    it('returns a valid metric in case of special chars', function()
      local key = 'service_id:s1,app_id:ai,app_key:ak,metric:m/1'
      local report = keys_helper.report_from_key_batched_report(key)
      assert.same({ service_id = 's1', app_id = 'ai', app_key = 'ak', metric = 'm/1' }, report)

      key = 'service_id:s1,app_id:ai,app_key:ak,metric:m_1'
      report = keys_helper.report_from_key_batched_report(key)
      assert.same({ service_id = 's1', app_id = 'ai', app_key = 'ak', metric = 'm_1' }, report)


      key = 'service_id:s1,app_id:ai,app_key:ak,metric:m%1'
      report = keys_helper.report_from_key_batched_report(key)
      assert.same({ service_id = 's1', app_id = 'ai', app_key = 'ak', metric = 'm%1' }, report)
    end)

    it('returns a report given a key of a batched report with user key', function()
      local key = 'service_id:s1,user_key:uk,metric:m1'

      local report = keys_helper.report_from_key_batched_report(key)
      assert.same({ service_id = 's1', user_key = 'uk', metric = 'm1' }, report)

      key = 'service_id:s1,user_key:you-&$#!!!,metric:m1'
      report = keys_helper.report_from_key_batched_report(key)
      assert.same({ service_id = 's1', user_key = 'you-&$#!!!', metric = 'm1' }, report)

      -- Base64
      key = 'service_id:s1,user_key:aGVsbG93b3JsZAo=,metric:m1'
      report = keys_helper.report_from_key_batched_report(key)
      assert.same({ service_id = 's1', user_key = 'aGVsbG93b3JsZAo=', metric = 'm1' }, report)

    end)

    it('returns an error when user_key has space', function()
      local key = 'service_id:s1,app_id:ai,app_key:I have spaces,metric:m%1'
      assert.returns_error('credentials not found', keys_helper.report_from_key_batched_report(key))

      key = 'service_id:s1,user_key:I have spaces,metric:m1'
      assert.returns_error('credentials not found', keys_helper.report_from_key_batched_report(key))
    end)

    it('returns a report given a key of a batched report with access token', function()
      local key = 'service_id:s1,access_token:'..tostring(access_token)..',metric:m1'

      local report = keys_helper.report_from_key_batched_report(key)
      assert.same({ service_id = 's1', access_token = tostring(access_token), metric = 'm1' }, report)
    end)

    it('returns a report given a key of a batched report with app ID only', function()
      local key = 'service_id:s1,app_id:ai,metric:m1'

      local report = keys_helper.report_from_key_batched_report(key)
      assert.same({ service_id = 's1', app_id = 'ai', metric = 'm1'}, report)

      -- special chars
      key = 'service_id:s1,app_id:!#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~,metric:m1'
      report = keys_helper.report_from_key_batched_report(key)
      assert.same({ service_id = 's1', app_id = '!#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~', metric = 'm1'}, report)
    end)

    it('returns an error when key has no credentials', function()
      local key = 'service_id:s1,app_id:,metric:m1'

      assert.returns_error('credentials not found', keys_helper.report_from_key_batched_report(key))
    end)
  end)
end)
