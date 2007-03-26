require 'basetrait'
require 'timeout'

#WARNING non working code. I have not thought this through.
#no locking what so ever has been implemented yet.
class ExecTrait
    include BaseTrait
    def init()
        @version = 0.1
        @inspect = "#{@inspect}"
        @timeout = 10
    end
    def run(cmd, args)
        return exec_system(cmd + " " + args)
    end
    def exec_system(cmdstr)
        puts "executing: #{cmdstr}"
        f = IO.popen("#{cmdstr}")
        pid = Process.pid
        Process::detach pid
        # $? will hold term status after Process.wait
        $execthread.save_pid(@_id, f, pid)
        res = $execthread.get_next(@_id)
        if $execthread.has_next(@_id)
            @me.more(1)
        end
        return res
    end

    def next(id,cmd,args)
        res = $execthread.get_next(id)
        if $execthread.has_next(id)
            @me.more(1)
        end
        return res
    end
end

class ExecThread
    def initialize(pthread)
        @parent = pthread
        @fd_store = {}
        @pid_store = {}
        @data_store = {}
        @thread = Thread.new {
            puts "initialize: execthread"
            run()
        }
    end
    def run()
        #run around looking for data
        begin
            while true
                if @fd_store.keys.length == 0
                    next
                end
                fdin = []
                @fd_store.values.each { |fd|
                    fdin << fd if !fd.nil?
                }
                ready = select(fdin, nil, nil, 1)
                next if !ready
                for s in ready[0]
                    id = @fd_store.index(s)
                    if id.nil?
                        puts "id is nill ? should not happen."
                        next
                    end
                    if s.eof?
                        s.close()
                        @fd_store.delete(id)
                        break
                    end
                    str = s.gets
                    @data_store["#{id}"] << str
                end
            end
        rescue Exception => detail
            puts "Exception: #{detail.message()}"
            begin
                del = []
                @fd_store.keys.each { |key|
                    fd = @fd_store[key] 
                    del << key if fd.nil? || fd.closed?
                }
                del.each { |key|
                    @fd_store.delete(key)
                }
            rescue Exception => detail
                puts ">> Exception: #{detail.message()}"
            end
            #assume some one will restart us.
        end
    end

    def save_fd(id,fd)
        tfd = @fd_store["#{id}"]
        if !tfd.nil?
            #kill your select and comeback
            @thread.kill
            @thread = Thread.new {
                puts "reinit select thread.."
                run
            }
        end
        @fd_store["#{id}"] = fd
        @data_store["#{id}"] = []
    end
    def save_pid(id,fd,pid)
        save_fd(id,fd)
        @pid_store["#{id}"] = pid
    end
    def has_next(id)
        #check if the array has enough
        #lock it here TODO:
        arr = @data_store["#{id}"]
        return true if !is_eof(id)
        return true if !arr.nil? && arr.length > 0
        return false
    end

    def is_eof(id)
        fd = @fd_store["#{id}"]
        return true if fd.nil?
        return false
    end

    def get_next(id)
        arr = @data_store["#{id}"]
        if arr.nil? || arr.length == 0
            arr = @data_store["#{id}"]
        end
        #lock here TODO:
        res = arr.shift if !arr.nil? && arr.length > 0
        @data_store["#{id}"] = arr
        return res
    end
end

$execthread = ExecThread.new(Thread.current) if $execthread.nil?

@traits['exec'] = ExecTrait.new(self)
