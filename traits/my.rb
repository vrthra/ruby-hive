require 'basetrait'
require 'thread'

self.reload('i')
class MyTrait < ITrait
end

@traits['my'] = MyTrait.new(self)
