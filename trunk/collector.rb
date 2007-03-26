module Collector
    #todo - use inject
    def sum(var1,var2)
        return var2 if var1.strip.length == 0
        return "#{var1.to_f + var2.to_f}"
    end
    def product(var1,var2)
        return var2 if var1.strip.length == 0
        return "#{var1.to_f * var2.to_f}"
    end
    def all(var1,var2)
        return var2 if var1.strip.length == 0
        return "#{var1 && var2}"
    end
    def any(var1,var2)
        return var2 if var1.strip.length == 0
        return "#{var1 || var2}"
    end
    def count(var1,var2)
        return "1" if var1.strip.length == 0
        return "#{var1.to_i + 1}"
    end
    def uniq(var1,var2)
        return var2 if var1.strip.length == 0
        "#{var1}".split(/:/).each {|v|
            return "#{var1}" if "#{v}" == "#{var2}"
        }
        return "#{var1}:#{var2}"
    end
end
