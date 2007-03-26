procedure :os do |str|
    resp = []
    query 'select $my:os from #hive' do |machine,value|
        resp << {:machine => machine,:val => value}
    end

    #sort them and send them back.
    resp.sort {|x,y| x[:val] <=> y[:val] }.each do |r|
        reply r[:machine] + ' -> ' + r[:val]
    end
end
