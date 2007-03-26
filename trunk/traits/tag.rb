require 'basetrait'
class TagTrait
    include BaseTrait
    def init()
        @version = 0.1
        @tag = {}
    end
    def run(cmd, args)
        case cmd
        when /^del$/
            @tag.delete($args.strip)
            return "#{@tag.keys.join(' ')}"
        when /^keys$/
            return "#{@tag.keys.join(' ')}"
        when /^values$/
            return "#{@tag.values.join(' ')}"
        when /^all$/
            return "#{@tag}"
        when /^has$/
            if !@tag[args].nil?
                return "true"
            else
                return "false"
            end
        else
            if !args.nil? and args.length > 0
                return @tag[cmd.strip] = args.strip
            else
                return @tag[cmd.strip]
            end
        end
    end
end
@traits['tag'] = TagTrait.new(self)
