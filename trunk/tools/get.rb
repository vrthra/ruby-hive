require 'net/http'
def get( resource )
    begin
        response = Net::HTTP.get_response(URI.parse(resource))
        if response.code.to_i == 200
            return response.body
        else
            puts "=>#{response.code}"
        end
    end
end

puts get(ARGV.shift)
