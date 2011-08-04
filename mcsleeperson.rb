# FULL DISCLAIMER:
# I was very drunk when I wrote this. Using my mojito recipe may aide in your 
# debugging efforts.
#
# In a 16-oz mixing glass, gently muddle together:
# * 1 large sprig spearmint
# * .75 oz simple syrup
# Then add:
# * Half a spent lime hull
# * 1 oz of lime juice (no less, no more)
# * 2 oz white rum
# * 3 oz sparkling mineral water
#
# Crushed ice on top! Mmmmmm....

require 'rubygems'
require 'sinatra'
require 'datamapper'
require 'haml'

DB_PATH = File.absolute_path(File.join(File.dirname(__FILE__), 'eventlog.sqlite'))
# DataMapper::Logger.new($stdout, :debug) # uncomment to see queries!
DataMapper.setup(:default, "sqlite://#{DB_PATH}")
puts "Loading DB from: #{DB_PATH}"

class SleepSession
  attr_reader :start_time, :end_time, :duration
  include DataMapper::Resource
  storage_names[:default] = 'ZSLEEPSESSION'
  
  has n, :sleep_events, :child_key => [:ZSLEEPSESSION]
  
  property :id, Serial, :field => 'Z_PK'
  property :raw_start_time, Float, :field => 'ZSESSIONSTART'
  property :raw_end_time, Float, :field => 'ZSESSIONEND'
  
  # Times are based upon NSDate's timeIntervalSinceReferenceDate -- seconds
  # since January 1st, 2001, GMT. WTF Apple, epoch not good enough for you?!
  
  def start_time
    (Time.utc(2001, 1, 1) + self.raw_start_time).localtime
  end
  
  def end_time
    (Time.utc(2001, 1, 1) + self.raw_end_time).localtime
  end
  
  def duration
    end_time - start_time rescue 0 # deal with unmarked end/start times lazily :P
  end
  
end

class SleepEvent
  attr_reader :time
  include DataMapper::Resource
  storage_names[:default] = 'ZSLEEPEVENT'
  
  belongs_to :sleep_session
  
  property :id, Serial, :field => 'Z_PK'
  property :type, Integer, :field => 'ZTYPE'
  property :intensity, Float, :field => 'ZINTENSITY'
  property :raw_time, Float, :field => 'ZTIME'
  
  def time
    (Time.utc(2001, 1, 1) + self.raw_time).localtime
  end
  
end

# Finalize the model for use in the application!
DataMapper.finalize

get '/' do
  @session_count = SleepSession.count
  @show_sessions = params.fetch('sessions', 7).to_i
  @sessions = SleepSession.all(:order => [:raw_start_time.desc], :limit => @show_sessions)
  @events = @sessions.map{|s| s.sleep_events}.flatten!
  haml :history
end