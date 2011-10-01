#!/usr/bin/env ruby

$: << File.expand_path(File.dirname(__FILE__)+"/modules")

require 'YAML'
require 'fileutils'
require 'Find'
require 'net/http'
require 'singleton'
require 'webrick'
require 'webrick'
include WEBrick
#require 'Tempfile'
require 'java'
require 'platform'
require 'mu_mysql'

def log(action, msg="")
    printf("%20s %s\n", action, msg)
end


class Node
    attr_accessor :source, :user
end

class Repo
    attr_accessor :sharing, :global, :user, :org

    def lroot
        "#{ENV['HOME']}/.mu"
    end
        
    def sharing
        if ! @sharing
            @sharing = "#{lroot}/lib"
        end
        @sharing
    end

    def shadow
        "#{lroot}/shadow"
    end

    def global
        #World::instance.node.source
        @org
    end

    def put(f)
        d="#{sharing}"
        FileUtils.mkdir_p d
        FileUtils.cp(f,d)
    end

    def push(f)
        proc="scp #{f} #{World::instance.node.user}@#{global}:mu/lib/"
        exec proc
    end

    def inject(objs)
        proc="scp #{objs.join ' '} #{World::instance.node.user}@#{global}:public_html/mu/lib/"
        exec proc
    end

    def check(f)
        d="#{sharing}"
        d+"/"+f
    end

    def exec(proc)
        p = IO.popen "sh -c \"#{proc}\""
        Process.wait p.pid
        $?.exitstatus > 0 && (puts p.readlines; puts "failed on \"#{proc}\""; Process.exit(1))
    end

    def execs(proc)
        p = IO.popen "sh -c \"#{proc}\""
        p.readlines
    end

    def world
        Net::HTTP.get_print("http://#{global}", '/mu/lib/contents')
    end

    def resolve(dep)
        if ! File.directory? sharing
            FileUtils.mkdir_p sharing
        end
        files=Dir.glob("#{sharing}/#{dep}")
        if files.size == 0
            if File.exist? "#{dep}/mu"
                FileUtils.cd(dep) do
                    child = load_mu '.'
                    child.install
                    child.artifacts.each { |d|
                        files << check(d)
                    }
                end
            end
        end
        if files.size == 0
            # fetch from remote
            s = shadow
            if ! File.directory?(s)
                response = Net::HTTP.get_response(global, '/mu/lib/contents')
                if response.code != 200
                    print "no global repo: get from #{global} failed: #{response.code}\n"
                    contents = []
                else
                    contents = response.body.split ' '
                end
                #contents = Net::HTTP.get(global, '/mu/lib/contents').split ' '
                contents.map! { |c| s+"/"+c }
                FileUtils.mkdir_p s
                FileUtils.touch contents
            end
            files=Dir.glob("#{s}/#{dep}").map! {|f| File.basename f}
            tmp="#{lroot}/tmp"
            FileUtils.mkdir_p tmp
            #files.each { |f| Net::HTTP.start(global) { |http|
                #re = http.get("/mu/lib/#{File.basename(f)}")
                #tf = "#{tmp}/#{File.basename(f)}"
                #open(tf) { |file|
                    #file.write(re.body)
                #}
                #puts File.size(tf)
                #FileUtils.mv(tf, "#{sharing}/#{File.basename(f)}")
            #} }
            files.each { |f|
                exec "curl -Ss -o #{tmp}/#{f} http://#{global}/mu/lib/#{f}"
                FileUtils.mv("#{tmp}/#{f}", "#{sharing}")
            }
            files=Dir.glob("#{sharing}/#{dep}")
        end
        if files.size == 0
            puts "cannot find #{dep}"
            Process.exit 1
        end
        files
    end

end

class Mu<Repo
    attr_accessor :proj, :ver, :type, :db, :uses, :main, :lang, :repo, :key, :dir, :sysargs

    def initialize
        super
    end

    def global
        @org
    end

    def create(organization, project, language, types={})
        @org = organization
        @proj = project
        @ver = '0.1'
        @lang = language.downcase
        @type = types
        if File.exists?(proj)
            puts "#{proj} already exists"
            Process.exit 1
        end
        FileUtils.mkdir_p proj
        FileUtils.cd(proj) do
            File.open('mu', 'w') do |out|
                #s=YAML.dump(self)
                #s.sub!(/.*?\n/, '')
                #out.puts s
                out.puts "org:  #{@org}\n"
                out.puts "proj: #{@proj}\n"
                out.puts "ver:  #{@ver}\n"
                out.puts "lang: #{@lang}\n"
                out.puts "type:\n"
                @type.each { |t| out.puts "  - #{t}\n" }
                out.puts "uses:\n"
            end
            created = load_mu '.'
            created.bloom
        end
    end

    def clean(t=nil)
        go('clean', t)
    end

    def scratch
        clean
        FileUtils.rm_rf lroot
    end

    def run(t=nil)
        go('run', t)
    end

    def bloom(t=nil)
        go('bloom', t)
    end

    def package(t=nil)
        go('package', t)
    end

    def test(t=nil)
        go('test', t)
    end

    def image(t=nil)
        go('image', t)
    end

    def install(t=nil)
        go('install', t)
    end

    def libname(t=nil)
        go('libname', t)
    end

    def artifacts(t=nil)
        go('artifacts', t).uniq
    end

    def post(t=nil)
        go('post', t)
    end

    def initdb(t=nil)
        if @db
            m = eval "Mu_#{@db}.new"
            m.mu = self
            m.init
        end
    end

    def actions
        ['package', 'image', 'install', 'post', 'run', 'clean']
    end

    def go(cmd, types=nil)
        last=[]
        if @dir==nil
            eval "self.#{cmd}"
        else
            if ! types
                types = type
            end
            types.each { |t|
                x = (eval "#{lang.capitalize}_#{t}.new")
                x.mu = self
                x.recent = File.mtime("#{dir}/mu")
                last << eval("x.#{cmd}")
            }
            last.flatten!
        end
        last
    end

    def server(t=nil)
        s = HTTPServer.new(:Port=>8080)
        trap("INT") { s.shutdown }
        #s.mount('/build', HTTPServlet::FileHandler, "#{@dir}/target", true)
        s.mount('/', Summary)
        s.start
    end
end

class Summary<HTTPServlet::AbstractServlet
    def do_GET(req, res)
        mu = load_mu '.'
        res['Content-Type'] = 'text/html'
        if req.path == '/'
            b = <<-EOB
                <html><head><title>#{mu.proj} #{mu.ver}</title>
                <style type='text/css'>
                    body {
                        background: #dddddd;
                        font:    12px/1.2 Monaco, Vera Sans, Verdana, Helvetica, sans-serif;
                        padding:0px;
                        margin:0px;
                        border:0px;
                    }

                    .title {
                        width: 100%;
                        background: #888888;
                        color: #dddddd;
                        padding: 20px;
                        margin: 0px;
                        font-size: 22px;
                    }

                    td {
                        padding-right: 10px;
                        margin: 0px;
                        padding-top: 0px;
                    }

                    .header {
                        font-size: 14px;
                        margin: 20px;
                    }

                    .actions {
                        margin-left: 20px;
                        margin-top: 0px;
                        padding-top: 10px;
                    }

                    .listing {
                        margin: 20px;
                    }
                </style>
                </head>
                <body>
                    <p class='title'>#{mu.proj} #{mu.ver}</p>
                    <p class='actions'>
                    <table border='0'><tr>
                    #{mu.actions.map { |a| "<td><form name=\"#{a}\" action=\"/command/#{a}\" method='POST'><input type='submit' value=\"#{a}\"/></form></td>" }.join '' }
                    </tr></table>
                    </p>
                    <p class='header'>Artifacts</p>
                    <p class='listing'>
                    #{mu.artifacts.map { |a| "<a href='somewhere'>#{a}</a><br/>" }.join '' }
                    </p>
                </body>
                </html>
            EOB
            res.body = b
        end
    end
end

class Build<HTTPServlet::AbstractServlet
    def do_GET(req, res)
        res.body = 'hello.'
        res['Content-Type'] = 'text/html'
    end
end

class Command<HTTPServlet::AbstractServlet
    def do_GET(req, res)
    end
end

class World
    include Singleton

    def node
        if ! @node
            r = File.dirname $0 
            print "dir: #{r}\n"
            if r == "/usr/bin"
                d = "/etc/"
            elsif r == "/usr/local/bin"
                d = "/usr/local/etc/"
            else
                d = r+"/../etc/"
            end
            file=IO.read(d+'mu')
            @node = YAML::load("--- !ruby/object:YAML::Node\n#{file}")
        end
        @node
    end
end

def load_mu(dir)
    file=IO.read(dir+'/mu')
    mu = YAML::load("--- !ruby/object:YAML::Mu\n#{file}")
    mu.dir = dir
    mu
end

mu = nil
if ARGV.size > 0
    last = []
    for command in ARGV
        # special cases
        if command=='version'
            puts '1.0'
        elsif command=='put'
            mu = Mu.new
            ARGV[1..-1].each { |a| mu.put a }
            break
        elsif command=='bloom'
            ARGV.shift
            if ARGV.length<4
                puts "usage: mu bloom org proj lang type type ..."
                Process.exit 1
            end
            mu = Mu.new
            mu.create(ARGV.shift, ARGV.shift, ARGV.shift, ARGV)
            break
        elsif command=='world'
            mu = Mu.new
            mu.world
        elsif command=='inject'
            ARGV.shift
            mu = Mu.new
            mu.inject ARGV
            break
        else
            if mu==nil
                if File.exists? 'mu'
                    mu = load_mu '.'
                else
                    mu = Mu.new
                end
            end
            (type, cmd, refuse) = command.split '.'
            if ! cmd
                cmd = type
                type = nil
            end
            last << eval("mu.#{cmd} type")
        end
    end
else
    mu = load_mu '.'
    mu.go 'package'
end
