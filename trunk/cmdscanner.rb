require 'strscan'
require 'netutils'
module Scanner
    class CmdScanner
        include NetUtils
        class Token
            def initialize(str)
                @str = str
            end
            def to_s
                return @str
            end
        end

        class TWord < Token
        end

        class TWhere < TWord
            def initialize
                @str = 'where '
            end
        end
        
        class TWhen < TWord
            def initialize
                @str = 'when '
            end
        end

        class TDo < TWord
            def initialize
                @str = 'do '
            end
        end

        class TTrait < Token
            def initialize(trait,method)
                @trait = trait
                @method = method
                @str = "$#{@trait}:#{@method}"
            end
            def obj
                @trait
            end
            def method
                @method
            end
        end

        class TDelim < Token
        end

        class TOParen < Token
            def initialize()
                @str = '('
            end
        end

        class TEscape < Token
            def initialize()
                @str = "\\"
            end
        end

        class TStart < Token
            def initialize()
                @str = ""
            end
        end

        class TCParen < Token
            def initialize()
                @str = ')'
            end
        end

        class TOSquare < Token
            def initialize()
                @str = '['
            end
        end

        class TCSquare < Token
            def initialize()
                @str = ']'
            end
        end

        class TOBraces < Token
            def initialize()
                @str = '{'
            end
        end

        class TCBraces < Token
            def initialize()
                @str = '}'
            end
        end
        #=======================================================
        #We are interested in just a few tokens:
        # <$><token><.><token>
        # <$><token><.><token><(> ... <)>
        # <$><token><.><token><[> ... <]>
        #=======================================================

        def scan()
            begin
                return if @expr.nil? || @expr.length == 0
                e = StringScanner.new(@expr)
                #does it start with !? if it does, strip it.
                rclass = 'a-zA-Z0-9_-'
                tok = Regexp.new("[#{rclass}]+")
                notok = Regexp.new("[^\\t \\[\\]\\(\\)\\{\\}\\$\\\\#{rclass}]+")
                c = -1
                @result = []
                if e.scan(/!/)
                    @result << TStart.new
                end
                while !e.eos?
                    if e.pos() == c
                        puts "partial:[now:#{@result}][rest:#{e.rest}]"
                        return "partial:[now:#{@result}][rest:#{e.rest}]"
                    end
                    c = e.pos()

                    if res = e.scan(/[ \t]+/) 
                        @result << TDelim.new(res)
                        next
                    end
                    if res = e.scan(/do /) 
                        @result << TDo.new()
                        next
                    end
                    if res = e.scan(/where /) 
                        @result << TWhere.new()
                        next
                    end
                    if res = e.scan(/when /) 
                        @result << TWhen.new()
                        next
                    end
                    if res = e.scan(/\$(#{tok})\:(#{tok})/) 
                        @result << TTrait.new(e[1],e[2])
                        next
                    end
                    if res = e.scan(/\$/)
                        @result << TDelim.new('$')
                        next
                    end
                    if res = e.scan(notok)
                        @result << TDelim.new(res)
                        next
                    end
                    if res = e.scan(tok)
                        @result << TWord.new(res)
                        next
                    end
                    if res = e.scan(/\[/)
                        @result << TOSquare.new
                        next
                    end
                    if res = e.scan(/\]/)
                        @result << TCSquare.new
                        next
                    end
                    if res = e.scan(/\(/)
                        @result << TOParen.new
                        next
                    end
                    if res = e.scan(/\)/)
                        @result << TCParen.new
                        next
                    end
                    if res = e.scan(/\{/)
                        @result << TOBraces.new
                        next
                    end
                    if res = e.scan(/\}/)
                        @result << TCBraces.new
                        next
                    end

                    if res = e.scan(/[\\]/)
                        @result << TEscape.new
                        next
                    end

                end
            rescue Exception => e
                carp e
            end
        end

        def initialize(expr)
            @expr = expr
            scan
        end

        def result
            return @result
        end

    end

    class StrStich
        include NetUtils
        #It is a big string
        #the expression is the initial value of bool exp which when turned on
        #starts the ruby mode, and in off mode becomes a string
        def dostr
            @dostr
        end

        def wherestr
            @wherestr
        end

        def whenstr
            @whenstr
        end

        def initialize(results)
            @whenstr = ''
            @wherestr = ''
            @dostr = ''
            str = ''
            br = []
            sq = 0
            cur = ''
            return if results.nil?
            count = 0
            while results.length > count
                res = results[count]
                count += 1
                case res.class.to_s
                when /TStart/, /TEscape/
                    str << res.to_s
                when /TDo/
                    #do we have any where strings yet?
                    if br.empty? && sq.zero?
                        case cur
                        when 'TWhere'
                            @wherestr = str
                        when 'TWhen'
                            @whenstr = str
                        end
                        str = ''
                        cur = 'TDo'
                    else
                        str << res.to_s
                    end
                when /TWhere/
                    if br.empty? && sq.zero?
                        case cur
                        when 'TDo'
                            @dostr = str
                        when 'TWhen'
                            @whenstr = str
                        end
                        str = ''
                        cur = 'TWhere'
                    else
                        str << res.to_s
                    end
                when /TWhen/
                    if br.empty? && sq.zero?
                        case cur
                        when 'TWhere'
                            @wherestr = str
                        when 'TDo'
                            @dostr = str
                        end
                        str = ''
                        cur = 'TWhen'
                    else
                        str << res.to_s
                    end
                when /TTrait/
                    str << res.to_s
                when /TWord/ ,/TDelim/
                    str << res.to_s
                when /TOParen/
                    br << ')'
                    str << '('
                when /TCParen/
                    s = br.pop
                    str << s
                when /TOBraces/
                    str << '{'
                    sq += 1
                when /TCBraces/
                    sq -= 1
                    str << '}'
                when /TOSquare/
                    str << '['
                when /TCSquare/
                    str << ']'
                else
                    puts "Unrecognized token:#{res} -> #{res.class.to_s}"
                end
            end
            case cur
            when /TDo/
                #remember it is a big string
                @dostr = str
            when /TWhere/
                @wherestr = str
            when /TWhen/
                @whenstr = str
            else
                puts "cur = #{cur}"
            end
            #carp "dostr = #{@dostr}"
            #carp "wherestr = #{@wherestr}"
            #carp "whenstr = #{@whenstr}"
        end
        def to_s
            @result
        end
    end


    class CmdStich
        include NetUtils
        #It is a big string
        #the expression is the initial value of bool exp which when turned on
        #starts the ruby mode, and in off mode becomes a string
        def dostr
            return <<EOS
s=<<ES
#{@dostr.gsub(/_REMOVE_/,'')}
ES
EOS
        end

        def wherestr
            if @wherestr.length > 0
                return @wherestr
            else
                return '1'
            end
        end

        def whenstr
            return "" if @whenstr.strip.length == 0
            return <<EOS
s=<<ES
#{@whenstr.gsub(/_REMOVE_/,'')}
ES
EOS
        end

        def initialize(results,cmd='invoke')
            @whenstr = ''
            @wherestr = ''
            @dostr = ''
            str = ''
            id = 0
            br = []
            sq = 0
            init_exp = false
            exp = init_exp
            brace = 0
            cur = ''
            return if results.nil?
            count = 0
            while results.length > count
                res = results[count]
                count += 1
                case res.class.to_s
                when /TStart/
                    str << res.to_s
                when /TEscape/
                    #the next one is to be taken literally
                    str << results[count]
                    count += 1
                when /TDo/
                    #do we have any where strings yet?
                    if br.empty? && sq.zero?
                        case cur
                        when 'TWhere'
                            @wherestr = str.gsub(/([^!~=]+)=([^!~=]+)/, "\\1==\\2").gsub(/<>/, "!=")
                        when 'TWhen'
                            @whenstr = str
                        end
                        str = ''
                        cur = 'TDo'
                        exp = false
                    else
                        str << res.to_s
                    end
                when /TWhere/
                    if br.empty? && sq.zero?
                        case cur
                        when 'TDo'
                            @dostr = str
                        when 'TWhen'
                            @whenstr = str
                        end
                        str = ''
                        cur = 'TWhere'
                        exp = true
                    else
                        str << res.to_s
                    end
                when /TWhen/
                    if br.empty? && sq.zero?
                        case cur
                        when 'TWhere'
                            @wherestr = str.gsub(/([^!~=]+)=([^!~=]+)/, "\\1==\\2").gsub(/<>/, "!=")
                        when 'TDo'
                            @dostr = str
                        end
                        str = ''
                        cur = 'TWhen'
                        exp = false
                    else
                        str << res.to_s
                    end
                when /TTrait/
                    if results[count].class.to_s =~ /TOSquare/
                        count += 1
                        if exp
                            str << "@traits['#{res.obj}'].#{cmd}(#{id},'#{res.method}',%Q{"
                            br << "})"
                        else
                            str << "#_REMOVE_{@traits['#{res.obj}'].#{cmd}(#{id},'#{res.method}',%Q{"
                            br << "})}"
                        end
                    else
                        if exp
                            str << "@traits['#{res.obj}'].#{cmd}(#{id},'#{res.method}','')"
                        else
                            str << "#_REMOVE_{@traits['#{res.obj}'].#{cmd}(#{id},'#{res.method}','')}"
                        end
                    end
                    id += 1
                when /TWord/
                    str << res.to_s
                when /TDelim/
                    str << res.to_s
                when /TOParen/
                    str << '('
                when /TCParen/
                    str << ')'
                when /TOBraces/
                    #change the exp type if this is the first instance
                    if exp
                        str << '{'
                    else
                        str << '#{'
                    end
                    exp = true if brace.zero?
                    brace += 1
                when /TCBraces/
                    brace -= 1
                    exp = init_exp if brace.zero?
                    str << '}'
                when /TOSquare/
                    br << ']'
                    str << '['
                when /TCSquare/
                    s = br.pop
                    if results[count] && results[count].class.to_s =~ /TOSquare/ && s =~ /\)\}/
                        count += 1
                        br << ']}'
                        str << '})['
                    else
                        if s =~ /\}/
                            exp = init_exp 
                        end
                        str << s
                    end
                else
                    puts "Unrecognized token:#{res} -> #{res.class.to_s}"
                end
            end
            case cur
            when /TDo/
                #remember it is a big string
                @dostr = str
            when /TWhere/
                @wherestr = str.gsub(/([^!~=]+)=([^!~=]+)/, "\\1==\\2").gsub(/<>/, "!=")
            when /TWhen/
                @whenstr = str
            else
                puts "cur = #{cur}"
            end
            #carp "dostr = #{@dostr}"
            #carp "wherestr = #{@wherestr}"
            #carp "whenstr = #{@whenstr}"
        end
        def to_s
            @result
        end
    end

    if __FILE__ == $0
        exp = ARGV.shift.to_i == 0
        while s = STDIN.gets
            c = CmdScanner.new s.chomp
            r = CmdStich.new(c.result,exp)
            puts "do=#{r.dostr}"
            puts "where=#{r.wherestr}"
            puts "when=#{r.whenstr}"
        end
    end
end
