module PatLib
    require 'socket'
    #==============================================    
    #exclusive cache stuff
    #==============================================    
    $cache_file_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890,_"

    def cache_dir_char(digest)
        idx = digest[2..3].hex & 63
        char = $cache_file_chars[idx]
        hex = sprintf("%0X",char)
        return hex
    end

    def cache_dir(digest)
        subsection = cache_dir_char(digest)
        idx = digest[0..1].hex & ($cache_ndirs - 1)
        s = $all_sects[idx.to_s]
        part = s['part']
        sect = s['sect']
        return part + '/' + sect + '/' + subsection + '/' + digest
    end

    def cache_path(url)
        digest = Digest::MD5.hexdigest(url).upcase[0..15]
        path = cache_dir(digest)
    end

    def send_request(url)
        User.new(Net::HTTP.new($webhost,$webport.to_i,$proxy_host,$proxy_port.to_i), url )
        #verify_cache 'http://'+ $webhost + ':' + $webport + url
    end

    def verify_cache(url)
        cache = cache_path(url)
        if FileTest.exist? cache then
            @log.info "Cached #{url}"
            @log.info "as #{cache}"
            File.delete cache
        else
            @log.info "Failure checking for #{cache}"
            @log.info "Failure cant find #{url}"
            exit
        end
    end

    def ip_addr()
        return IPSocket.getaddress(@options.server_host).gsub(/\./,',')
    end
end
