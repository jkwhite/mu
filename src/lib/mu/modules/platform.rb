class Platform
    attr_accessor :uses, :name
end

class Platform_MacOS<Platform
    def initialize
        @name='Mac OS'
    end

    def uses(d)
        File.extname(d)=='.jnilib' || File.extname(d)=='.dylib'
    end

    def package(mu, recent)
        dmgdir="target/#{mu.proj.capitalize}.app"
        rsrc="#{dmgdir}/Contents/Resources"
        macos="#{dmgdir}/Contents/MacOS"
        FileUtils.mkdir_p rsrc
        FileUtils.mkdir_p macos
        FileUtils.mkdir_p "#{rsrc}/Java"
        libs="target/#{mu.proj}-#{mu.ver}/lib/*.jar"
        infop = "
<?xml version='1.0' encoding='UTF-8'?>
<!DOCTYPE plist PUBLIC '-//Apple Computer//DTD PLIST 1.0//EN' 'http://www.apple.com/DTDs/PropertyList-1.0.dtd'>
<plist version='1.0'>
<dict>
    <key>CFBundleExecutable</key>
    <string>JavaApplicationStub</string>
    <key>CFBundleIconFile</key>
    <string>#{mu.proj}.icns</string>
    <key>CFBundleIdentifier</key>
    <string>#{mu.main}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>1.0</string>
    <key>CFBundleName</key>
    <string>Tower</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleVersion</key>
    <string>#{mu.ver}</string>
    <key>Java</key>
    <dict>
        <key>MainClass</key>
        <string>#{mu.main}</string>
        <key>JVMVersion</key>
        <string>1.5</string>
        <key>ClassPath</key>
        <string>#{Dir.glob(libs).map { |j| "$JAVAROOT/lib/#{File.basename j}" }.join(':') }</string>
        <key>WorkingDirectory</key>
        <string>$JAVAROOT</string>
        <key>Properties</key>
        <dict>
            <key>apple.laf.useScreenMenuBar</key>
            <string>true</string>
            <key>com.apple.mrj.application.apple.menu.about.name</key>
            <string>#{mu.proj.capitalize}</string>
            <key>java.library.path</key>
            <string>$JAVAROOT/lib</string>
        </dict>
    </dict>
</dict>
</plist>
        "
        (File.open("#{dmgdir}/Contents/Info.plist", "w")<<infop).close
        if ( File.exists? "#{mu.proj}.icns" )
            FileUtils.cp "#{mu.proj}.icns", rsrc
        end
        FileUtils.cp_r Dir.glob("target/#{mu.proj}-#{mu.ver}/*"), "#{rsrc}/Java"
        if (! (File.exists? "#{macos}/JavaApplicationStub" ) )
            exec "ln -s /System/Library/Frameworks/JavaVM.framework/Resources/MacOS/JavaApplicationStub #{macos}/JavaApplicationStub"
        end
    end
end

class Platform_Linux<Platform
    def initialize
        @name='Linux'
    end

    def uses(d)
        File.extname(d)=='.so'
    end

    def package(mu, recent)
        tarfile="target/#{mu.proj}-#{mu.ver}.tbz2"
        if((! File.exist? tarfile) || recent > File.mtime(tarfile))
            proc = "tar cjf #{tarfile} -C 'target' #{mu.proj}-#{mu.ver}"
            exec(proc)
            1
        end
        0
    end
end

class Platform_Windows<Platform
    def initialize
        @name='Windows'
    end

    def uses(d)
        File.extname(d)=='.dll'
    end

    def package(mu, recent)
    end
end
