class Lang
    attr_accessor :mu, :recent

    def initialize()
        #@sharing="#{ENV['HOME']}/.mu"
        @deps=nil
    end

    def exec(proc)
        @mu.exec(proc)
    end

    def execs(proc)
        @mu.execs(proc)
    end

    def deps()
        if ! mu.uses
            []
        else
            if @deps==nil
                @deps=[]
                for u in mu.uses
                    @deps << mu.resolve(u)
                end
                @deps.flatten!
            end
            @deps
        end
    end

    def modules()
        mods=[]
        for u in mu.uses
            files=Dir.glob("#{mu.sharing}/#{u}")
            if files.size == 0
                if File.exist? "#{u}/mu"
                    child = load_mu
                end
            end
        end
        mods
    end

    def proceed(out, ins)
        go=0
        if File.exist? out
            m = File.mtime out
            for i in ins
                if File.mtime(i) > m
                    go=1
                    break
                end
            end
        else
            go=1
        end
        go
    end

    def update(from, to)
        if (! File.exist?to) || File.mtime(from) > File.mtime(to)
            FileUtils.cp(from, to)
            @recent = File.mtime to
            1
        else
            0
        end
    end
end

