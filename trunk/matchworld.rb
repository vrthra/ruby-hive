module MatchWorld
    #===================Match world=====================
    class Match
        def initialize(opt, store)
            @store = store
            @log = store.log
            match = {}
            class << match
                def [](*args)
                    key = args.shift
                    if include? key
                        s = fetch(key)
                        return s[0] if args.empty?
                        num = args.shift
                        val = s[1][num]
                        raise "Matches does not contain group #{num} for (#{key}). possible groups [#{s.length}]" if val.nil?
                        return val
                    else
                        raise "Matches does not contain (#{key}). possible [#{keys.join(',')}]"
                    end
                end
            end
            Thread.current['matches'] = match
            if opt.keys.collect{|x|x.to_s}.include?('seq')
                @delegate = SeqMatch.new(opt, MatchLine.new(store), store)
            else
                @delegate = FullMatch.new(opt, MatchLine.new(store), store)
            end
        end
        def compare(exp, data)
            return @delegate.compare(exp,data)
        end
    end

    class SeqMatch
        def initialize(opt, linematcher, store)
            @strict = opt.keys.collect{|x|x.to_s}.include?('strict')
            @linematcher = linematcher
            @log = store.log
        end
        def compare(exp, data)
            expidx = 0
            dataidx = 0
            while true
                curexp = exp[expidx]
                curdata = data[dataidx]
                if @linematcher.compare(curexp, curdata)
                    expidx += 1
                    dataidx += 1
                    return true if expidx == exp.length
                    next
                else
                    if @strict
                        raise "[#{curexp}] != [#{curdata}]"
                    end
                    dataidx += 1
                    if dataidx == data.length
                        raise curexp
                        return false 
                    end
                    next
                end
            end
            return true
        end
    end

    class FullMatch

        def initialize(opt, linematcher, store)
            @linematcher = linematcher
            @log = store.log
        end

        def compare(exp, data)
            exp.each do |curexp|
                curexp.chomp!
                @log.info("exp: #{curexp}")
                found = false
                data.each do |curdata|
                    curdata.chomp!
                    if @linematcher.compare(curexp, curdata)
                        found = true
                        break
                    end
                end
                if !found
                    raise curexp
                end
            end 
            return true
        end
    end

    class TreeMatch
        #dummy for xml matching
        def compare(exp, data)
            return true
        end
    end

    #-----------------------------------------
    class MatchLine
        def initialize(store)
            @log = store.log
        end
        def compare(exp, data)
            @log.matchlines "[#{exp}] <> [#{data}]"
            #find the type of exp
            return true if exp.nil?
            case exp.chomp
            when /^[ \t]*\/(.*)\//
                return false if data.nil?
                val = regex_compare($1, data.chomp)
                if val 
                    Thread.current['matches'][$1] = [data.chomp,val]
                    return true
                end
            when /^[ \t]*\?(.*)\?/
                return true if data.nil?
                val = regex_compare($1, data.chomp)
                if !val
                    Thread.current['matches'][$1] = [data.chomp,nil]
                    return true
                end
            when /^[ \t]*#.*/
                return true
            else
                return false if data.nil?
                val = ((exp.chomp <=> data.chomp) == 0)
                Thread.current['matches'][exp] = [data,nil] if val
                return val
            end
        end

        def regex_compare(exp,data)
            return Regexp.new(exp).match(data)
        end
    end

end
