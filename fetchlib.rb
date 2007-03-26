module Fetchlib
    require 'net/http'
    require 'pathname'
    class Page
        def initialize(wget, rbase, lbase, cont)
            @cont = cont
            if rbase !~ /\/$/
                @out = init_file(wget, rbase, lbase)
            else
                @out = init_dir(wget, rbase, lbase)
            end
        end
        def out
            return @out
        end
        def init_file(wget, rbase, lbase)
            @cont.log "file:#{rbase}"
            if lbase.nil?
                return wget.fetch(rbase)
            else
                wget.write(rbase, lbase)
                @cont.out lbase.chomp
            end
        end
        def init_dir(wget, rbase, lbase)
            @cont.log "dir:#{rbase}"
            #assume a directory page
            txt = wget.fetch(rbase)
            #parse txt and fill @file and @dir
            @file = []
            @dir = []
            @base = rbase
            parse_txt(txt)

            if lbase.nil?
                return @dir + @file
            else
                #mkdir lbase
                lbase = lbase + '/' if lbase !~ /\/$/
                @cont.log lbase.chomp
                Pathname.new(lbase.chomp).mkpath()
            end


            @file.each {|path|
                url = rbase + path
                dest = lbase + path
                page = Page.new(wget, url, dest, @cont)
            }
            @dir.each {|path|
                url = rbase + path
                dest = lbase +  path
                page = Page.new(wget,url, dest, @cont)
            }
        end

        def parse_txt(txt)
            txt.each {|line|
                case line
                when /HREF="([^ ?]*\/) *"/
                    dir = $1
                    if line !~ /Parent Directory<\/A>/i
                        if dir !~ /\.\./ and dir.strip !~ /^\/$/ and dir.strip.length != 0
                            @dir << dir
                        end
                    end
                when /HREF="([^ ?]+)"/
                    file = $1
                    if file !~ /\.\./
                        @file << file
                    end
                end
            }
            if @dir.length + @file.length == 0
                puts "no files found. check your url"
            end
        end
    end

    class Fetch
        def initialize(session,cont)
            @sock = session
            @cont = cont
        end
        def fetch(path)
            path.chomp!
            r, d = @sock.get(path)
            raise "NotFound #{r.code} #{path}" if r.code != '200'
            return d
        end
        def write(uri,path)
            i = 0
            File.open(path,'wb') {|f|
                @sock.get(uri) do |str|
                    @cont.p '.' if i%1024 == 0
                    i += 1
                    f.write str
                end
            }
        end
    end
    class Controller
        def initialize(host, port,src, dest=nil)
            @out = []
            @log = []
            @status = ""
            puts "open #{host}:#{port}"
            Net::HTTP.new(host, port,nil).start do |h|
                begin
                    wget = Fetch.new(h,self)
                    if dest.nil?
                        page = Page.new(wget,src, nil, self)
                        @out = page.out
                    else
                        page = Page.new(wget,src, dest, self)
                        log "#{src} -> #{dest}"
                    end
                    @status = "created:#{@out.length}"
                rescue Exception => detail
                    puts "You are unlucky...#{detail.message()}"
                    puts detail.backtrace.join("\n")
                    @status = detail.message
                end
            end
        end
        def close()
        end
        def p(str)
            print str
            STDOUT.flush
        end
        
        def out(str)
            @out<< str
        end
        def log(str)
            @log << str
        end
        def count()
            return @out.length
        end
        def status()
            return @status
        end
        def gets()
            return @out.shift
        end
        def getbuf()
            return @out
        end
        def getlog()
            return @log.shift if @log.length > 0
            return nil
        end
        def eof?()
            return true if @out.empty?
            return false
        end
    end
    #to use:
    #controller = Controller.new(host, port, src, dest)
end
