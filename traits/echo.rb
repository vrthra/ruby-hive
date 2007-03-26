#register in @me['system']
require 'basetrait'
require 'pathname'
class EchoTrait
    include BaseTrait
    #init() - intensional.
    def initialize(me)
        @version = 0.1
        @inspect = ""
    end
    def invoke(id, cmd, args)
        return "#{cmd} #{args}"
    end
end
@traits['echo'] = EchoTrait.new(self)
