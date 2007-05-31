#!/usr/local/bin/ruby
#Heavily adapted from mikiwiki.

require 'cgi'
require 'yaml'
require 'fileutils'
include YAML
class Wiki
    def initialize(name)
        @name = name
        @db = WikiDB.new(@name)
        @hive = restore('hive.yaml') || {
            :meta => { :code => { :start => "<div class='code'>", :end => '</div>' }},
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
            m = %(<a href="#{CGI::escape(pname)}.html">#{aname}</a>)
        else
            m = %(#{aname}<a href="#{CGI::escape(pname)}.html">?</a>)
        end
    end

    def linking(str,page)
        #custom
        @link.keys.each {|exp|
            str.gsub!(Regexp.new(exp)){|m|
                m = %(<a href="#{$~[@link[exp][:page]]}.html">#{$~[@link[exp][:name]]}</a>)
            }
        }

        #normal link
        str.gsub!(/\[\[(.+?)\]\]/){|m|
            pname = $1
            case pname
            when /(.+?)\|(.*?)\|(\d+?)\|(\d+?)\|(.+)/
                begin
                    alt = $1
                    lnk = $2
                    width = $3
                    height = $4
                    src = $5
                    if width =~ /^0+$/
                        width = ""
                    else
                        width = "width='#{width}'"
                    end
                    if height =~ /^0+$/
                        height = ""
                    else
                        height = "height='#{height}'"
                    end
                    if /.+\.((jpe?g)|(gif)|(png)|)/ =~ src
                        if lnk.nil? || (lnk =~ /^ *$/)
                            m = %(<img src="#{src}" alt="#{alt}" #{width} #{height} border='0' />)
                        else
                            m = %(<a href="#{lnk}"><img src="#{src}" alt="#{alt}" #{width} #{height} border='0' /></a>)
                        end
                    end
                rescue Exception => e
                    puts e.message
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
                    m = %(<a href="#{$2}">#{aname}</a>)
                else
                    if cname == 'edit'
                        m = %(<a href="#{page}">#{aname}</a>)
                    else
                        m = %(<a href="#{cname}">#{aname}</a>)
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
        return s.split(/\n/).collect{|str|
            cleanup(meta(linking(str,page)))
        }.collect{|str|
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
            return main_frame(convert(@db[page], page), page)
        end
    end

    def main_frame(content, page)
        return <<EOS
<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <link type="text/css" rel="stylesheet" href="hive.css" >
    <title>#{@name}</title>
</head>
<body>
    <p class="head">
#{convert("<table valign='top'><tr><td>[[hive|/Hive.html|50|50|hive.png]]</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td>[[Code:http://code.google.com/p/ruby-hive/]] |[[FrontPage]] |[[HiveTraits]] </td><tr></table>",page)}
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
    end

    def read(key)
        begin
            File::open("#{key}","r"){|f| return f.read }
        rescue
        end
    end

    def [](key)
        read(key)
    end

    def key?(key)
        exist?("#{key}")
    end

    def keys
        Dir.entries('*').delete_if{|e|
            if /\.\.?/ =~ e then true end
        }
    end
end

if __FILE__ == $0
html = '../html'
wiki = Wiki.new('hive')
arr = Dir["*"].collect{|c| c.downcase}
if (arr - arr.uniq).length > 0
    puts "Warning: conflicting names #{arr - arr.uniq}"
end
Dir["*"].each {|file|
    case file
    when /\.png$/
        FileUtils.cp(file, html + '/')
    when /\.yaml$/
    when /\.css$/
        FileUtils.cp(file, html + '/')
    when /\.cgi$/
    when /\.rb$/
    else
        page = wiki.disp(file)
        File.open(html + '/' + file + '.html', 'w+') {|f|
            f.write page
        }
    end
}
end

