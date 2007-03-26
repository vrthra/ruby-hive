module Transform
    class TabTrans
        def initialize(proxy)
            @proxy = proxy
        end
        def transform(data)
            data.collect! {|l|l.gsub(/\t/,@proxy)} if !data.nil?
        end
    end
    class CaseTrans
        def transform(data)
            data.collect! {|l|l.downcase} if !data.nil?
        end
    end
    class PrintTrans
        def transform(data)
            data.collect! {|l|l.dump} if !data.nil?
        end
    end
    class SqueezeTrans
        def transform(data)
            data.collect! {|l|l.squeeze(" ")} if !data.nil?
        end
    end
    class TrimTrans
        def transform(data)
            data.collect! {|l|l.strip} if !data.nil?
        end
    end
    class ChopTrans
        def transform(data)
            data.collect! {|l|l.chop} if !data.nil?
        end
    end
end
