DATABASES:=markov.sqlite3
SQLITE3:=sqlite3
CURL:=curl
MAXLINES:=5000

all: databases distfiles

clean:
	rm -f *.sqlite3* *.sql

scrub: clean

databases: $(DATABASES)
distfiles: dist/markov-data.sql

markov.sqlite3: src/sequence.sql src/markov.sql src/corporations.sql src/dist.female.first.sql src/dist.male.first.sql src/dist.all.last.sql src/data.sql
	rm -f $@*
	cat $^ | $(SQLITE3) $@
	$(SQLITE3) $@ analyze

%-data.sqlite3: %.sqlite3
	rm -f $@*
	cp $^ $@
	$(SQLITE3) $@ 'delete from markovconstruct'
	$(SQLITE3) $@ 'delete from markovresult'

dist/%.sql: %.sqlite3
	$(SQLITE3) $^ '.dump' > $@

src/%.sql: data/%
	rm -f $@
	ID=$$(if [ "$*" = "corporations" ]; then echo 2;\
	    elif [ "$*" = "dist.female.first" ]; then echo 3;\
	    elif [ "$*" = "dist.male.first" ]; then echo 4;\
	    elif [ "$*" = "dist.all.last" ]; then echo 5;\
		else echo 1; fi);\
	while read line; do echo "insert into vtrain (id, data) values ($${ID}, '$$(echo $${line} | sed s/\'/\\\'\\\'/g)');" >> $@; done < $^

data/dist.%: data/dist.%.census.gov
	cat $^ | cut -d ' ' -f 1 | head -n $(MAXLINES) - > $@

data/corporations: data/corporations.mass.gov
	cat $^ | cut -d ',' -f 1 | sed 's/^.[ \t\v]*//g' | uniq | sort --random-sort | head -n $(MAXLINES) - > $@

data/dist.%.census.gov:
	$(CURL) 'http://www.census.gov/genealogy/www/data/1990surnames/dist.$*' > $@

data/corporations.mass.gov:
	$(CURL) 'http://www.mass.gov/dor/docs/dls/mdmstuf/propertytax/corporations.txt' > $@
