require 'basetrait'
require 'thread'

self.reload('i')
class MeTrait < ITrait
end

@traits['me'] = MeTrait.new(self)
