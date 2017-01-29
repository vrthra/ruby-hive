#!/usr/local/bin/ruby
#Heavily adapted from mikiwiki.

require 'cgi'
require 'yaml'
include YAML
class Wiki
    def initialize(name, url)
        @name = name
        @url = url
        @db = WikiDB.new(@name)
        @hive = restore(@name + '/hive.yaml') || {
            :meta => { :code => { :start => "<div class='code'", :end => '</div>' }},
            :link => { '\$([a-z]+):' => { :name => 0, :page => 1 } }
        }
        @meta = @hive[:meta]
        @link = @hive[:link]
        @brs = []
    end

    def restore(file)
        File.open(file){|f| YAML::load(f)} if FileTest.exists?(file)
    end

    def make_link(pname, aname = nil)
        aname = pname if !aname
        if @db.key?(pname)
            m = %(<a href="#{@url+'?page='+ CGI::escape(pname)}">#{aname}</a>)
        else
            m = %(#{aname}<a href="#{@url+'?page='+ CGI::escape(pname)}">?</a>)
        end
    end

    def linking(str,page)
        #custom
        @link.keys.each {|exp|
            str.gsub!(Regexp.new(exp)){|m|
                m = %(<a href="#{@url}?page=#{$~[@link[exp][:page]]}">#{$~[@link[exp][:name]]}</a>)
            }
        }

        #normal link
        str.gsub!(/\[\[(.+?)\]\]/){|m|
            pname = $1
            case pname
            when /(.+?)\|(.*?)\|(\d+?)\|(\d+?)\|(.+)/
                alt = $1
                lnk = $2
                width = $3
                height = $4
                if /.+\.((jpe?g)|(gif)|(png)|)/ =~ $5
                    unless lnk
                        m = %(<img src="#{$&}" alt="#{alt}" width="#{width}" height="#{height}" border='0' />)
                    else
                        m = %(<a href="#{lnk}"><img src="#{$&}" alt="#{alt}" width="#{width}" height="#{height}" border='0' /></a>)
                    end
                end
            when /^([^:]+):(.+)/
                name = $1
                link = $2
                if name =~ /http|ftp|mailto|https|irc|svn/
                    m = %(<a href="#{pname}">#{pname}</a>)
                else
                    m = %(<a href="#{link}">#{name}</a>)
                end
            when /(.+?)>(.+)/
                m = make_link($2, $1)
            else
                m = make_link(pname)
            end
        }

        #mode
        str.gsub!(/\(\((.+?)\)\)/){|m|
            sstr = $1
            if /\(\((.+?)\|(.+)\)\)/ =~ m
                aname = $1
                cname = $2
                if /(.+?)\|(.+)/ =~ $2
                    m = %(<a href="#{@url}?mode=#{$1}&amp;page=#{$2}">#{aname}</a>)
                else
                    if cname == 'edit'
                        m = %(<a href="#{@url}?mode=#{cname}&amp;page=#{page}">#{aname}</a>)
                    else
                        m = %(<a href="#{@url}?mode=#{cname}">#{aname}</a>)
                    end
                end
            else
                case sstr
                when 'page'
                    m = page
                when 'copy'
                    m = "&copy;"
                end
            end
        }
        str
    end

    def meta(str)
        return case str.chomp when /^\|([^ \t:]+):(.*)/
        if @meta[$1.to_sym]
            @meta[$1.to_sym][:start] + $2 + @meta[$1.to_sym][:end] + '$'
        else
            "<#{$1}>" + $2 + "</#{$1}>" + '$'
        end
        #multilined.
        when /^\[([^ \t:]+):/
            if @meta[$1.to_sym]
                @brs  << @meta[$1.to_sym][:end]
                @meta[$1.to_sym][:start] + '$'
            else
                @brs << "</#{$1}>"
                "<#{$1}>" + '$'
            end
        when /^\] *$/
            (@brs.pop || '') + '$'
        else
            str
        end
    end

    def cleanup(str)
        str.gsub("\t", "&nbsp;&nbsp;&nbsp;&nbsp;").gsub("  ", "&nbsp;&nbsp;").gsub(/~+/){|m|
            if m == '~'
                m = ''
            else
                m = '~'
            end
        }.gsub(/<\|/,'&lt;').gsub(/\|>/,'&gt;').gsub(/~~/,'~')
    end

    def convert(s, page = nil)
        return s.split(/\n/).collect{|str|cleanup meta linking(str,page)}.collect{|str|
            case str
            when /(.*)\$$/
                $1
            else
                str + '<br/>'
            end
        }
    end

    def disp(page = 'FrontPage')
        page = 'FrontPage' unless page
        if @db.key?(page)
            main_frame(convert(@db[page], page), page)
        else
            edit(page)
        end
    end

    def edit(page)
        content = ""
        if @db.key?(page)
            content = @db[page]
        else
            content = "[[#{page}]]\n\n"
        end

        field = <<EOS
edit : #{page}
</p>
<form method="post" action="#{@url}">
<p>
<textarea name="data" cols="120" rows="60">#{CGI::escapeHTML(content)}</textarea><br />
<input type="hidden" name="mode" value="write" />
<input type="hidden" name="page" value="#{page}" />
<input type="submit" value="save" /> 
<input type="reset" value="clear" />
</p>
</form>
<p class="content">
EOS
        main_frame(field, page)
    end
    
    def put(page, data)
        if data == ""
            if @db.key?(page)
                @db.delete(page)
                disp
                return
            end
        else
            @db[page] = data
        end
    end

    def write(page, data)
        put(page, data)
        disp(page)
    end

    def index(exp = nil)
        list = <<HEAD
Index of #{@name}<br/><br/>
<form method='get' action='#{@url}'>
    <input type="text" name="filter" value="#{exp}" />
    <input type="hidden" name="mode" value="index" />
    <input type="submit" value="filter" /> 
</form>
HEAD
        if !exp
            exp = Regexp.new('.*') 
        else
            exp = Regexp.new(exp)
        end
        @db.keys.sort.each{|key|
            list += %(<a href="#{@url+'?page='+ key}">#{key}</a><br/>\n) if key =~ exp
        }
        main_frame(list, '')
    end

    def create
        field = <<EOS
create new wiki page.
</p>
<form method="post" action="#{@url}">
<p>
<input type="hidden" name="mode" value="edit" />
<input type="text" name="page" value="" />
<input type="submit" value="create" /> 
</p>
</form>
<p class="content">
EOS
        main_frame(field, '')
    end

    def style
        css = ""
        File::open("#{@name}/hive.css","r"){|f|
            css = f.read
        }
        print <<EOS
Content-type:text/css

#{css}
EOS
    end

    def main_frame(content, page)
        print <<EOS
Content-type:text/html

<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <link type="text/css" rel="stylesheet" href="/cgi-bin/site.css" >
    <link rel="stylesheet" type="text/css" href="#{@url}?mode=style" />
    <title>#{@name}</title>
</head>
<body>
    <p class="head">
#{convert(@db['PageHead'],page)}
    </p>
    <p class="content">
#{content}
    </p>
    <p class="tail">
#{convert(@db['PageTail'],page)}
    </p>
</body>
</html>
EOS
    end

    def has_page?(page)
        @db.key?(page)
    end
end

class WikiDB
    include FileTest

    def initialize(name)
        @name = name
        Dir.mkdir(@name) unless directory?(@name)
    end

    def read(key)
        begin
            File::open("#{@name}/#{key}","r"){|f| return f.read }
        rescue
        end
    end

    def write(key, value)
        File::open("#{@name}/#{key}","w"){|f|
            f.flock(File::LOCK_EX)
            f.print value
            f.flock(File::LOCK_UN)
        }
    end

    def [](key)
        read(key)
    end

    def []=(key,value)
        write(key, value)
    end

    def key?(key)
        exist?("#{@name}/#{key}")
    end

    def keys
        Dir.entries(@name).delete_if{|e|
            if /\.\.?/ =~ e then true end
        }
    end

    def delete(key)
        File::delete("#{@name}/#{page}")
    end

end

if __FILE__ == $0
    begin
        cgi = CGI.new
        wiki = Wiki.new('hive', 'hive.cgi')
        unless wiki.has_page?('PageHead')
            head = <<EOS
((New|create)) | [[FrontPage>FrontPage]] | ((Edit|edit)) | ((Index|index))
EOS
            wiki.put('PageHead',head)
        end

        unless wiki.has_page?('PageTail')
            tail = <<EOS
    
EOS
            wiki.put('PageTail',tail)
        end

        case cgi["mode"][0]
        when 'create'
            wiki.create
        when 'index'
            wiki.index cgi['filter']
        when 'edit'
            wiki.edit(cgi["page"][0])
        when 'write'
            wiki.write(cgi["page"][0],cgi["data"][0])
        when 'style'
            wiki.style
        else
            wiki.disp(cgi["page"][0])
        end
    rescue Exception
        print "Content-Type: text/plain\n\n"
        puts "#$! (#{$!.class})\n\n"
        puts $@.join( "\n" )
    end
end

