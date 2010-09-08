#!/usr/bin/env rackup -Ilib:../lib -s thin
require 'sinatra/async'
require 'eventmachine'
require 'sysuuid'

class AsyncTest < Sinatra::Base
  register Sinatra::Async

  enable :show_exceptions

  aget '/' do
    body "hello async"
  end

  aget '/delay/:n' do |n|
    EM.add_timer(n.to_i) { body { "delayed for #{n} seconds" } }
  end

  aget '/raise' do
    raise 'boom'
  end

  aget '/araise' do
    EM.add_timer(1) { body { raise "boom" } }
  end

  # This will blow up in thin currently
  aget '/raise/die' do
    EM.add_timer(1) { raise 'die' }
  end

  @@channels = {}

  put "/notifications/new" do
    id = sysuuid
    @@channels[id.to_s] = EM::Channel.new
    puts "Created channel #{id.to_s}"
    id+"\n"
  end

  put "/notifications/:n" do |n|
    channel = @@channels[n.to_s] and
      channel.push "Done"
    if channel
      puts "Pushed to channel #{n.inspect}"
    else
      puts "No channel #{n.inspect}"
    end
    "Ok, I told them\n"
  end

  aget "/notifications/:n" do |n|
    channel = @@channels[n.to_s]
    if channel
      puts "Subscribing to channel #{n.inspect}"
    else
      puts "No channel #{n.inspect}, can't subscribe"
    end
    channel and
      subscription = channel.subscribe { |msg|
	puts "Sending response to aget on channel #{n.inspect}"
	body(msg)
      } and
      on_close {
	puts "channel #{n.inspect} closed, unsubscribing"
	channel.unsubscribe(subscription)
      }
  end

end

run AsyncTest.new
