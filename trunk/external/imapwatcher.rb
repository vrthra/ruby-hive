require "thread"
require "servicestate"
require "net/imap"
require "ostruct"
require "yaml"
include YAML
class IMAPWatcher
  include ServiceState
  NEW = 0
  NOMATCH = 1
  EXCEPTION = 0

  # the time to wait before checking the directories again
  attr_accessor :sleepTime, :priority

  def initialize()
    @sleepTime = $config['mail.sleeptime'] || 30
    @priority = 0
    @stopWhen = nil

    @watchThread = nil
    @expressions = {}
    
    initializeState()

  end

  def add(name,exp)
      @expressions[name] = exp
  end

  def remove(name)
      @expressions.delete(name)
  end

  def clear
      @expressions.clear
  end

  def start(&block)
      if isStarted? then
          raise RuntimeError, "already started"
      end

      setState(STARTED)

      # we watch in a new thread
      @watchThread = Thread.new do
          # we will be stopped if someone calls stop or if someone set a stopWhen that becomes true
          while !isStopped? do
              begin
                  host = $config['mail.host'] || 'mail-apac.sun.com'
                  user = $config['mail.user'] || nil
                  pass = $config['mail.pass'] || nil

                  raise 'No credentials ' if !user || !pass

                  imap = Net::IMAP.new(host,993,true)
                  imap.login(user, pass)
                  box = $config['mail.box'] || 'HIVE'
                  imap.select(box)
                  #imap.examine(box)
                  # SEEN ANSWERED FLAGGED DELETED DRAFT RECENT ALL NEW
                  mails = $config['mail.type'] || 'RECENT'
                  imap.search([mails]).each do |message_id|
                      envelope = imap.fetch(message_id, 'ENVELOPE')[0].attr['ENVELOPE']
                      if envelope
                          mail = envelope.subject
                          from = envelope.from[0]
                          id = (from.mailbox || '' )+ '@' + (from.host || '')
                          mail = "#{id}:#{envelope.subject}"
                          @expressions.values.each do |val|
                              if mail =~ Regexp.new(val)
                                  #response = imap.fetch(message_id, "RFC822.TEXT")
                                  #puts response.attr['RFC822.TEXT']
                                  begin
                                      block.call(NEW, mail)
                                  rescue Exception => e
                                      puts e.message
                                      puts e.backtrace.join("\n")
                                  end

                                  # SEEN ANSWERED FLAGGED DELETED DRAFT RECENT
                                  addflags = $config['mail.addflags'] || nil
                                  remflags = $config['mail.remflags'] || [:Seen]
                                  copyto = $config['mail.copyto'] || nil
                                  imap.store(message_id, "-FLAGS", remflags) if remflags
                                  imap.store(message_id, "+FLAGS", remflags) if addflags
                                  if copyto
                                      imap.create('Mail/'+copyto) if not imap.list('Mail/', copyto)
                                      imap.copy(message_id, "Mail/"+copyto)
                                  end
                                  #puts "deleted"
                                  imap.expunge if addflags && addflags.include?(:Deleted)
                                  #puts "after expunge"
                              #else
                              #    begin
                              #        block.call(NOMATCH, mail)
                              #    rescue Exception => e
                              #        puts e.message
                              #        puts e.backtrace.join("\n")
                              #    end
                              end
                          end
                      end
                  end
                  imap.close()
                  #           imap.disconnect()

              rescue Exception => e
                  block.call(NEW, e.message)
                  puts e.message
                  puts e.backtrace.join("\n")
              end
              sleep(@sleepTime)
          end
      end
      # set the watch thread priority
      @watchThread.priority = @priority
  end

  # kill the filewatcher thread
  def stop()
      setState(STOPPED)
      @watchThread.wakeup()
  end

  # wait for the filewatcher to finish
  def join()
      @watchThread.join() if @watchThread
  end

end

#--- main program ----
if __FILE__ == $0
  watcher = IMAPWatcher.new()
  watcher.add("mytest",'mytest')
  watcher.sleepTime = 10

  test = false
  watcher.stopWhen {
    test == true
  }

  watcher.start() { |status,msg|
    if status == IMAPWatcher::NEW then
      puts "created: #{msg}"
    else
      puts "unknown: #{msg}"
    end
  }

  sleep(200)
  test = true
  watcher.join()
end
