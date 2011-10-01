require 'lang'


class Java<Lang
    def initialize()
        super
        @recent = nil
        @target = 'target'
    end

    def bloom
        FileUtils.mkdir_p 'src/main'
        FileUtils.mkdir_p 'src/test'
    end

    def clean()
        FileUtils.rm_rf([@target])
        #modules().each { |m| }
    end

    def image()
    end

    def package()
    end

    def libname()
        "#{mu.proj}-#{mu.ver}.jar"
    end

    def artifacts
        [libname]
    end

    def jar()
        jarfile="target/#{mu.proj}-#{mu.ver}.jar"
        if compile() || (! File.exist? jarfile) || @recent > File.mtime(jarfile)
            man={ 'Name' => mu.proj, 'Vendor' => mu.org, 'Version' => mu.ver }
            mu.main && man['Main'] = mu.main
            mkjar(jarfile, Dir.entries('target/classes').delete_if {|d| d[0] == ?.}.map! { |c| "target/classes/#{c}" },
                man, :flatten => true
            )
            @recent = File.mtime jarfile
            1
        end
    end

    def install()
        lib='target/'+libname
        if package() || (! File.exist? "#{mu.sharing}/#{lib}")
            mu.put('target/'+libname())
            1
        end
        0
    end

    def mkjar(jar, files, manifest, options={})
        m=Tempfile.new "manifest"
        manifest.each_pair { |key, value| m.puts "#{key}: #{value}" }
        m.close
        entries=files
        if options[:flatten]
            entries.map! { |c| "-C #{File.dirname(c)} #{File.basename(c)}" }
        end
        proc="jar cmf #{m.path} #{jar} #{entries.join(' ')}"
        exec proc
        m.delete
    end

    def test
        compile
        junit=mu.resolve 'junit-3.8.1.jar'
        do_compile(['test/java', 'test'], ['resources', 'res'], 'test-classes', ['target/classes', junit])
        reports="target/test-report"
        cp = deps
        [junit, 'target/classes', 'target/test-classes'].each { |d| cp << d }
        root = "src/test/java/"
        if ! (File.directory? root)
            root = "src/test/"
        end
        path = cp.join(":")
        Find.find(root) do |f|
            if FileTest.directory?(f)
                if File.basename(f)[0] == ?.
                    Find.prune
                else
                    next
                end
            elsif f =~ /Test.*\.java/
                proc = "java -cp #{path} junit.textui.TestRunner #{f.sub(root,'').sub('.java','').gsub('/','.')}"
                exec proc
            end
        end
    end

    def compile
        do_compile(['main/java', 'main'], ['resources', 'res'], 'classes')
    end

    def do_compile(srcs, ress, dst, add_classpath=[])
        comp=[]
        copy=[]
        dest="target/#{dst}"
        #dest='target/classes'
        #src='src/main/java'
        src = nil
        for s in srcs
            if File.directory?("src/#{s}")
                src = "src/#{s}"; break
            end
        end
        resdir = nil
        for r in ress
            if File.directory?("src/#{r}")
                resdir = "src/#{r}"; break
            end
        end
        #srcs.each { |s|
            #if File.directory?(s)
                #puts "found #{s}"
                #src = s; break
            #end
        #}
        #if ! (File.directory?(src))
            #src='src/main'
        #end
        if src!=nil && (File.directory? src)
            Find.find(src) do |f|
                if FileTest.directory?(f)
                    if File.basename(f)[0] == ?.
                        Find.prune
                    else
                        next
                    end
                elsif File.extname(f) == '.java'
                    fd = f.sub(src,dest).sub('.java', '.class')
                    if (! File.exist? fd) || File.mtime(f) > File.mtime(fd)
                        comp << f
                    end
                else
                    fd = f.sub(src,dest)
                    if (! File.exist? fd) || File.mtime(f) > File.mtime(fd)
                        copy << f
                        FileUtils.mkdir_p(File.dirname(fd))
                    end
                end
                if @recent==nil || File.mtime(f) > @recent
                    @recent = File.mtime(f)
                end
            end
        end
        [ dest ].each { |d| FileUtils.mkdir_p(d) }
        if comp.size > 0
            cp = ""
            if deps.length+add_classpath.length>0
                cp = "-cp #{(deps+add_classpath).join(':')}"
            end
            proc="javac -g -sourcepath #{src} #{cp} -d #{dest} #{comp.join(' ')}"
            #p = IO.popen "sh -c \"#{proc} 2>/dev/null\""
            p = IO.popen "sh -c \"#{proc}\""
            Process.wait p.pid
            $?.exitstatus > 0 && Process.exit(1)
        end
        copy.each { |c| FileUtils.cp(c, c.sub(src,dest)) }
        
        res=[]
        rdir=resdir
        if rdir!=nil && File.directory?(rdir)
            Find.find(rdir) do |f|
                if FileTest.directory?(f)
                    if File.basename(f)[0] == ?.
                        Find.prune
                    else
                        next
                    end
                else
                    fd = f.sub(rdir,dest)
                    if (! File.exist? fd) || File.mtime(f) > File.mtime(fd)
                        res << f
                        FileUtils.mkdir_p(File.dirname(fd))
                    end
                end
            end
            res.each { |c| FileUtils.cp(c, c.sub(rdir,dest)) }
        end
        copy.size > 0 || comp.size > 0 || res.size > 0
    end
end

class Java_lib<Java
    def post()
        install()
        push libname
    end

    def package()
        jar()
    end
end

class Java_app<Java
    def tar_t(tarfile)
        (execs "tar tjf #{tarfile}").map! { |f| f.strip! }
    end

    def post
        install
        push "target/#{mu.proj}-#{mu.ver}.tbz2"
    end

    def artifacts
        super << "#{mu.proj}-#{mu.ver}.tbz2"
    end

    def install
        if super
            mu.put "target/#{mu.proj}-#{mu.ver}.tbz2"
            1
        else
            0
        end
    end

    def package()
        #@platforms=[Platform_MacOS.new, Platform_Linux.new, Platform_Windows.new]
        @platforms=[Platform_Linux.new, Platform_MacOS.new, Platform_Windows.new]
        if(image())
            @platforms.each { |p| p.package(mu, @recent) }
            1
        end
        0
        #tarfile="target/#{mu.proj}-#{mu.ver}.tbz2"
        #if(image() || (! File.exist? tarfile) || @recent > File.mtime(tarfile))
            #proc = "tar cjf #{tarfile} -C 'target' #{mu.proj}-#{mu.ver}"
            #exec(proc)
            #1
        #end
        #0
    end

    def image()
        img = "#{@target}/#{mu.proj}-#{mu.ver}"
        lib = "#{img}/lib"
        if jar() || (! File.exist? img) || @recent > File.mtime(img)
            ['bin', 'lib'].each { |d| FileUtils.mkdir_p("#{img}/#{d}") }
            cp=[]
            deps.each { |d|
                case File.extname d
                    when '.tbz2'
                        cp << tar_t(d).delete_if { |f| File.extname(f)!='.jar' }.map { |f| File.basename f }
                        FileUtils.cd img do
                            #exec "tar --strip-path=1 -xjf #{d}"
                            exec "tar --strip-components=1 -xjf #{d}"
                        end
                    when '.jar'
                        cp << d
                        FileUtils.cp(d, "#{lib}")
                    else
                        FileUtils.cp(d, "#{lib}")
                end
            }
            cp << "#{@target}/#{mu.proj}-#{mu.ver}.jar"
            cp.flatten!
            FileUtils.cp("#{@target}/#{mu.proj}-#{mu.ver}.jar", lib)
            #cp.each { |d| FileUtils.cp(d, "#{lib}") }
            etc=[]
            edir="src/etc"
            if File.directory?(edir)
                dest="#{img}/etc"
                Find.find(edir) do |f|
                    if FileTest.directory?(f)
                        if File.basename(f)[0] == ?.
                            Find.prune
                        else
                            next
                        end
                    else
                        fd = f.sub(edir,dest)
                        if (! File.exist? fd) || File.mtime(f) > File.mtime(fd)
                            etc << f
                            FileUtils.mkdir_p(File.dirname(fd))
                        end
                    end
                end
                etc.each { |c| FileUtils.cp(c, c.sub(edir,dest)) }
            end
            if @mu.main
                boot = '#!/bin/sh
                    base=`cd $(dirname $0)/..; pwd`
                    export LD_LIBRARY_PATH=$base/lib:$LD_LIBRARY_PATH
                    export DYLD_LIBRARY_PATH=$base/lib:$DYLD_LIBRARY_PATH
                    '
                boot="#{boot} [ \"`uname | grep Darwin`\" ] && dock=\"-Xdock:name=#{mu.proj.capitalize}\"
                "
                #boot="#{boot} java #{mu.sysargs} -Dapp.root=`dirname $0`/.. -Dapple.laf.useScreenMenuBar=true -Djava.library.path=$base/lib $dock -cp $base/lib/#{cp.collect { |c| File.basename(c) }.join(':$base/lib/')} #{mu.main} $*
                boot="#{boot} java #{mu.sysargs} -Dapp.root=`dirname $0`/.. -Dapple.laf.useScreenMenuBar=true -Djava.library.path=$base/lib $dock -cp `find $base/lib -name \*.jar | tr '\\n ' :` #{mu.main} $*
                "
                (File.open("#{img}/bin/#{mu.proj}", "w")<<boot).close
                File.chmod(0755, "#{img}/bin/#{mu.proj}")
            end
            1
        end
    end

    def run()
        image()
        exec "#{@target}/#{mu.proj}-#{mu.ver}/bin/#{mu.proj}"
    end
end

class Java_web<Java
    def initialize
        super
        @platforms=[Platform_MacOS.new, Platform_Linux.new, Platform_Windows.new]
    end

    def run()
    end

    def post
        package
        push "target/#{mu.proj}-jnlp-#{mu.ver}.tbz2"
    end

    def artifacts
        super << "#{mu.proj}-jnlp.tbz2"
    end

    def package()
        tarfile="target/#{mu.proj}-jnlp-#{mu.ver}.tbz2"
        if(image() || (! File.exist? tarfile) || @recent > File.mtime(tarfile))
            proc = "tar cjf #{tarfile} -C 'target' #{mu.proj}-jnlp"
            exec(proc)
            1
        end
        0
    end

    def jnlp_dir()
        "#{@target}/#{mu.proj}-jnlp"
    end

    def sign(jar, main=nil)
        # clear manifest to unsign jar
        delete_metainf(jar)
        if main
            update_manifest(jar, {'Main-Class' => main})
        end
        proc="jarsigner -storepass changeit #{jar} #{mu.org}"
        exec proc
        @recent = File.mtime jar
    end

    def pack_native(platform, libs)
        res="<resources os=\"#{platform.name}\">\n"
        if libs.size > 0
            jar="#{jnlp_dir()}/native-#{platform.name.delete(' ')}.jar"
            if proceed(jar, libs)
                mkjar(jar, libs, {}, :flatten=>true)
                sign jar
                @recent = File.mtime jar
            end
            res="#{res}<nativelib href=\"#{File.basename jar}\"/>\n"
        end
        "#{res}</resources>\n"
    end
 
    def pack_jar(lib, main=nil)
        jar="#{jnlp_dir()}/#{File.basename(lib)}"
        if update(lib, jar)
            sign(jar, main)
        end
        "<jar href=\"#{File.basename(jar)}\"/>\n"
    end

    def delete_metainf(jar)
        exec "zip -d #{jar} META-INF/\*"
    end

    def update_manifest(jar, manifest)
        m=Tempfile.new 'man'
        manifest.each_pair { |key, value| m.puts "#{key}: #{value}" }
        m.close
        exec "jar umf #{m.path} #{jar}"
        m.delete
    end

    def image()
        FileUtils.mkdir_p jnlp_dir()
        jars=deps().select { |d| File.extname(d)=='.jar' }
        pack_jar("#{@target}/#{libname()}", mu.main)

        j=<<-EOJ
        <?xml version="1.0" encoding="UTF-8"?>
        <jnlp href="#{mu.proj}.jnlp" spec="1.0+" codebase="http://#{mu.org}/#{mu.proj}">
            <information>
                <title>#{mu.proj}</title>
                <vendor>#{mu.org}</vendor>
                <homepage href="index.html"/>
                <offine-allowed>
                </offine-allowed>
            </information>
            <security>
                <all-permissions/>
            </security>
            <resources>
                <j2se version="1.5+" max-heap-size="512m" initial-heap-size="128m"/>
                #{jars.collect { |d| pack_jar d } }
                <jar main="true" href="#{libname()}"/>
            </resources>
            #{@platforms.collect{ |p| pack_native(p, deps().select {|d| p.uses(d)}) } }
            <application-desc/>
        </jnlp>
        EOJ
        (File.open("#{jnlp_dir()}/#{mu.proj}.jnlp", "w")<<j).close
        1
    end
end

class Java_synthetic<Java
    def bloom
    end

    def package()
        tarfile="target/#{mu.proj}-#{mu.ver}.tbz2"
        if(image() || (! File.exist? tarfile) || @recent > File.mtime(tarfile))
            proc = "tar cjf #{tarfile} -C 'target' #{mu.proj}-#{mu.ver}"
            exec(proc)
            1
        end
        0
    end

 
    def image
        sdir="#{@target}/#{mu.proj}-#{mu.ver}"
        FileUtils.mkdir_p sdir
        FileUtils.cd(sdir) do
            deps.each { |d|
                case File.extname d
                    when '.tbz2'
                        #exec "tar --strip-path=1 -xjf #{d}"
                        exec "tar --strip-components=1 -xjf #{d}"
                    when '.jar'
                        FileUtils.cp(d, "lib/#{File.basename d}")
                    else
                        puts "skipping #{d}"
                end
            }
        end
        1
    end
end

