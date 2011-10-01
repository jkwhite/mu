class Mu_mysql
    attr_accessor :mu

    def init
        #print "mysql init #{@mu}\n"
        @mu.exec "mysql -u #{@mu.proj} -D#{@mu.proj} -p < src/sql/create.sql"
    end
end
