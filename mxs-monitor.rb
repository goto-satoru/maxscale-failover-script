#!/usr/bin/env ruby
# monitor status of MaxScale instances
# toggle "passive" paramter

require 'rest-client'
require 'json'

MONITOR_INTERVAL = 5  # seconds
TIMEOUT          = 2  # seconds

class MaxScale
  attr_accessor :hostname, :name, :mdbmon_state, :passive, :stopped

  def initialize(hostname, name)
    @hostname = hostname; @name=name; @mdbmon_state = ""; @passive=nil; @stopped=nil;
  end

  def check_status(print = false)
    uri = "http://admin:mariadb@#{@hostname}:8989/v1/maxscale"
    begin
      json = RestClient::Request.execute(method: :get, url: uri, timeout: TIMEOUT)
      results = JSON.parse(json)
      @passive = results['data']['attributes']['parameters']['passive']
#      printf "#{@name}(#{@hostname}) - passive = %-5s ", @passive if print
    rescue
      puts "!!! #{@name}(#{@hostname}): passive paramter retrieval timeout"
      @passive = nil
    end

    uri = "http://admin:mariadb@#{@hostname}:8989/v1/monitors/MariaDB-Monitor"
    begin
      json = RestClient::Request.execute(method: :get, url: uri, timeout: TIMEOUT)
      results = JSON.parse(json)
      @mdbmon_state = results['data']['attributes']['state']
      self.print_status if print
      @stopped = false
    rescue
      puts "!!! #{@name}(#{@hostname}): MaraiDB-Monitor state retrieval timeout"
      @mdbmon_state = 'Stopped'
      @stopped = true
    end

    return @passive
  end

  def set_passive(value)
    puts "#{@name}(#{@hostname}): passive => #{value}"
    begin
      if value
        system "maxctrl -h #{@hostname}:8989 alter maxscale passive true"
      else
        system "maxctrl -h #{@hostname}:8989 alter maxscale passive false"
      end
      self.check_status(true)
    rescue
      puts "!!! #{@name}(#{@hostname}): exception w/ set_passive"
      @stopped = true
      puts $!
    end
    return @stopped
  end

  def print_status
    print "#{@name}(#{@hostname}): "
    if @passive
      print "Passive "
    else
      print "Active  "
    end
    puts " MariaDB Monitor: #@mdbmon_state"
  end
end

if $0 == __FILE__
  # to be updated !!!
  mxs1 = MaxScale.new('mxs-921p', 'mxs1')
  p mxs1
  mxs2 = MaxScale.new('mxs-lk79', 'mxs2')
  p mxs2

  while true
    puts "----------------------------------------"
    puts Time.now

    mxs1.check_status(true)
    mxs2.check_status(true)
     
    if mxs1.mdbmon_state == "Stopped"
      puts "MaxScale on mxs1(#{mxs1.hostname}) stopped !!!"
      mxs2.set_passive(false)             # => active
    elsif mxs2.mdbmon_state == "Stopped"
      puts "MaxScale on mxs2(#{mxs2.hostname}) stopped !!!"
      mxs1.set_passive(false)             # => active
    end

    if mxs1.passive and mxs2.passive
      puts "*** passive=true on both mxs1/mxs2 ***"
      mxs1.set_passive(false)
      mxs2.set_passive(true)
    end

    if mxs1.passive == false and mxs2.passive == false
      puts "*** passive=false on both mxs1/mxs2 ***"
      mxs1.set_passive(false)
      mxs2.set_passive(true)
    end

    sleep MONITOR_INTERVAL
  end
end

# Disclaimer 
# this script is for demonstration purpose only. 
# No warranty or guarentee is implied or expressly granted.
