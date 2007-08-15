#
# crontab.rb
#
# A modified version of the original Crontab from RAA 
# here http://raa.ruby-lang.org/project/crontab/
=begin
= crontab.rb

== SYNOPSIS

  -----
     require "crontab"

     # case 1
     tab = Crontab.open("/var/cron/tabs/" + ENV['USER'])

     # case 2
     tab = Crontab.new
     tab.add("5,35 0-23/2 * * *"){system "a_program"}

     loop do
       tab.run
       sleep 60
     end
  -----

== DESCRIPTION

Crontab class represent crontab(5) file. 

== CLASS Crontab

=== CONSTANT

: Crontab::CRONTAB_VERSION
  A version string. 

=== CLASS METHOD

: open(filename)
  returns a new Crontab object from a crontab(5) file.

: new(str)
  returns a new Crontab object for str.  str is formatted in crontab(5).

=== METHOD

: add(str, job)
: add(str) do .... end
  adds a cron record. str format is same as the first five field of
  crontab(5).  A correspoinding job can be given by string job or a
  block.

: grep(time)
  returns an array consists of jobs which whould be invoked in time. 

: run
: run do |job| .... end
  invokes all job should be done now.  If a block is given, string jobs
  are passed to each block invocation.

== MODULE Crontab::CronRecord

This module is used to provide features to each cron record. 

=== METHOD

: min
: hour
: mday
: mon
: wday
  returns all times matching to each pattern. 

: command
  returns correspoding job. 

: run
: run do |job| .... end
  invokes the job immediately.  If a block is given, string jobs are
  passed to each block invocation.

== AUTHOR

Gotoken

== HISTORY

  2001-01-04: (BUG) camma and slash were misinterpreted <gotoken#notwork.org>
  2000-12-31: replaced Array#filter with collect! <zn#mbf.nifty.com>
  2000-07-06: (bug) Crontab#run throws block <gotoken#notwork.org>
  2000-07-03: (bug) open->File::open <gotoken#notwork.org>
  2000-04-07: Error is subclass of StandardError <matz#netlab.co.jp>
  2000-04-06: Fixed bugs. <c.hintze#gmx.net>
  2000-04-06: Started. <gotoken#notwork.org>
=end

module CronTab

class Crontab
  CRONTAB_VERSION = "2001-01-04"
  include Enumerable

  def Crontab.open(fn)
    new(File::open(fn).read)
  end
  def table
      return @table
  end

  def initialize(table_as_string = "")
    @table = parse(table_as_string)
  end

  def each(&block)
    @table.each(&block)
  end

  def add(str, job = nil, name="", info="", &action)
    job = action if block_given?
    @table.push((parse_timedate(str) << job << name << info ).extend(CronRecord))
  end

  attr_reader :table

  def run(*args, &block)
    grep(Time.now).each{|record|
      record.run(*args, &block)
    }
  end

  def grep(time)
    @table.find_all{|record|
      record.sec.include? time.sec and record.min.include? time.min and record.hour.include? time.hour and record.mday.include? time.mday and record.mon.include? time.mon and record.wday.include? time.wday
    }
  end

  def table()
      return @table
  end

  private
  def parse(str)
    res = []
    str.each{|line|
      next if /(\A#)|(\A\s*\Z)/ =~ line
      res.push(parse_timedate(line).
	       push(line.scan(/(?:\S+\s+){5}(.*)/).shift[-1]))
    }
    res.collect{|record|
      record.extend CronRecord
    }
  end

  def parse_timedate(str)
    second, minute, hour, day_of_month, month, day_of_week = 
      str.scan(/^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/).shift

    day_of_week = day_of_week.downcase.gsub(/#{WDAY.join("|")}/){
      WDAY.index($&)
    }

    arr = [
      parse_field(second,       0, 59),
      parse_field(minute,       0, 59),
      parse_field(hour,         0, 23),
      parse_field(day_of_month, 1, 31),
      parse_field(month,        1, 12),
      parse_field(day_of_week,  0, 6),
    ]
    return arr
  end

  def parse_field(str, first, last)
    list = str.split(",")
    list.map!{|r|
      r, every = r.split("/")
      every = every ? every.to_i : 1
      f,l = r.split("-")
      range = if f == "*"
		first..last
	      elsif l.nil?
		f.to_i .. f.to_i
	      elsif f.to_i < first
		raise FormatError.new("out of range (#{f} for #{first})")
	      elsif last < l.to_i
		raise FormatError.new("out of range (#{l} for #{last})")
	      else
		f.to_i .. l.to_i
	      end
      range.to_a.find_all{|i| (i - first) % every == 0}
    }
    list.flatten!
    list
  end

  module CronRecord
    def sec;     self[0]; end
    def min;     self[1]; end
    def hour;    self[2]; end
    def mday;    self[3]; end
    def mon;     self[4]; end
    def wday;    self[5]; end
    def command; self[6]; end
    def name;    self[7]; end
    def info;    self[8]; end

    def run(*args)
      case command
      when String
	if iterator?
	  yield(command)
	else
	  puts "-->"
	  puts "Message from #{$0} (pid=#{$$}) at #{Time.now}"
	  puts command
	  puts "EOF"
	end
      when Proc
	command.call(*args)
      end
    end
  end

  WDAY = %w(sun mon tue wed thu fri sat)

  class Error < StandardError; end
  class FormatError < Error; end
end

if __FILE__ == $0
#  tab = Crontab.new(<<"\r\n\r\n")
## run five minutes after midnight, every day
#5 0 * * *       $HOME/bin/daily.job >> $HOME/tmp/out 2>&1
## run at 2:15pm on the first of every month -- output mailed to paul
#15 14 1 * *     $HOME/bin/monthly
## run at 10 pm on weekdays, annoy Joe
#0 22 * * 1-5    mail -s "It's 10pm" joe%Joe,%%Where are your kids?%
#23 0-23/2 * * * echo "run 23 minutes after midn, 2am, 4am ..., everyday"
#5 4 * * sun     echo "run at 5 after 4 every sunday"
#\r\n\r\n
#  
#  [
#    Time.local(2000, 4, 5, 0, 5),
#    Time.local(2000, 4, 1, 14, 15),
#    Time.local(2000, 4, 5, 22, 0),
#    Time.local(2000, 4, 5, 22, 23),
#    Time.local(2000, 4, 9, 4, 5)
#  ].each{|t|
#    #print ">>> ", t, "\n"
#    #tab.grep(t).each{|r| p r.command}
#  }

  tab = Crontab.new
  #tab.add("23 0-23/2 * * *"){system "ls"}
  tab.add("* * * * * *", "...........................second", "mexico", "")
  tab.add("0 * * * * *", "...........................minute", "mexico-second", "")
  #tab.add("0 * * * *", "...........................hour")

  tab.table.each {|record|
      puts "name: #{record.name}"
      puts "cmd: #{record.command}"
      puts "#sec #{record.sec.length}: #{record.sec.join(',')}"
      puts "#min #{record.min.length}: #{record.min.join(',')}"
      puts "#hour #{record.hour.length}: #{record.hour.join(',')}"
      puts "#mday #{record.mday.length}: #{record.mday.join(',')}"
      puts "#mon #{record.mon.length}: #{record.mon.join(',')}"
      puts "#wday #{record.wday.length}: #{record.wday.join(',')}"
  }
  while true
      tab.run
      sleep 1
  end
end
end
