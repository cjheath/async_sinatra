gem 'test-unit'
require "test/unit"

require 'eventmachine'

require "sinatra/async/test"

class TestSinatraAsync < Test::Unit::TestCase
  include Sinatra::Async::Test::Methods

  class TestApp < Sinatra::Base
    set :environment, :test
    register Sinatra::Async

    # Hack for storing some global data accessible in tests (normally you
    # shouldn't need to do this!)
    def self.singletons
      @singletons ||= []
    end

    error 401 do
      '401'
    end

    aget '/hello' do
      body { 'hello async' }
    end

    aget '/em' do
      EM.add_timer(0.001) { body { 'em' }; EM.stop }
    end

    aget '/em_timeout' do
      # never send a response
    end

    aget '/404' do
      not_found
    end

    aget '/302' do
      ahalt 302
    end

    aget '/em_halt' do
      EM.next_tick { ahalt 404 }
    end

    aget '/s401' do
      halt 401
    end

    aget '/a401' do
      ahalt 401
    end

    aget '/async_close' do
      # don't call body here, the 'user' is going to 'disconnect' before we do
      env['async.close'].callback { self.class.singletons << 'async_closed' }
    end

    aget '/on_close' do
      # sugared version of the above
      on_close do
        self.class.singletons << 'async_close_cleaned_up'
      end
    end

    aget '/redirect' do
      redirect '/'
    end
  end

  def app
    TestApp.new
  end

  def test_basic_async_get
    get '/hello'
    assert_async
    async_continue
    assert last_response.ok?
    assert_equal 'hello async', last_response.body
  end

  def test_em_get
    get '/em'
    assert_async
    em_async_continue
    assert last_response.ok?
    assert_equal 'em', last_response.body
  end

  def test_em_async_continue_timeout
    get '/em_timeout'
    assert_async
    assert_raises(Test::Unit::AssertionFailedError) do
      em_async_continue(0.001)
    end
  end

  def test_404
    get '/404'
    assert_async
    async_continue
    assert_equal 404, last_response.status
  end

  def test_302
    get '/302'
    assert_async
    async_continue
    assert_equal 302, last_response.status
  end

  def test_em_halt
    get '/em_halt'
    assert_async
    em_async_continue
    assert_equal 404, last_response.status
  end

  def test_error_blocks_sync
    get '/s401'
    assert_async
    async_continue
    assert_equal 401, last_response.status
    assert_equal '401', last_response.body
  end

  def test_error_blocks_async
    get '/a401'
    assert_async
    async_continue
    assert_equal 401, last_response.status
    assert_equal '401', last_response.body
  end

  def test_async_close
    aget '/async_close'
    async_close
    assert_equal 'async_closed', TestApp.singletons.shift
  end

  def test_on_close
    aget '/on_close'
    async_close
    assert_equal 'async_close_cleaned_up', TestApp.singletons.shift
  end

  def test_redirect
    aget '/redirect'
    assert last_response.redirect?
    assert_equal 302, last_response.status
    assert_equal '/', last_response.location
  end
end