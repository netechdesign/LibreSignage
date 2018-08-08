##
##  LibreSignage makefile
##

NPMBIN := $(shell ./build/scripts/npmbin.sh)
ROOT := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

SASS_IPATHS := $(ROOT)src/common/css
SASSFLAGS := --sourcemap=none

# Directories.
DIRS := $(shell find src 								\
	\( -type d -path 'src/node_modules' -prune \)		\
	-o \( -type d -print \)								\
)

# Non-compiled sources.
SRC_NO_COMPILE := $(shell find src 						\
	\( -type f -path 'src/node_modules/*' -prune \)		\
	-o \( -type f -path 'src/api/endpoint/*' -prune \) 	\
	-o \(												\
		-type f ! -name '*.js'							\
		-a -type f ! -name '*.scss'						\
		-a -type f ! -name 'config.php' -print 			\
	\)													\
)

# SCSS sources.
SRC_SCSS := $(shell find src 							\
	\( -type f -path 'src/node_modules/*' -prune \) 	\
	-o \(												\
		-type f -name '*.scss' -print					\
	\)													\
)
DEP_SCSS := $(subst src,dist,$(SRC_SCSS:.scss=.scss.dep))

# JavaScript sources + dependencies.
SRC_JS := $(shell find src 								\
	\( -type f -path 'src/node_modules/*' -prune \)		\
	-o \( -type f -name 'main.js' -print \)				\
)
DEP_JS := $(subst src,dist,$(SRC_JS:.js=.js.dep))

# API endpoint sources.
SRC_ENDPOINT := $(shell find src/api/endpoint 			\
	\( -type f -path 'src/node_modules/*' -prune \)		\
	-o \( -type f -name '*.php' -print \)				\
)

# Documentation dist files.
HTML_DOCS := $(shell find src -type f -name '*.rst')
HTML_DOCS := $(addprefix dist/doc/html/,$(notdir $(HTML_DOCS)))
HTML_DOCS := $(HTML_DOCS:.rst=.html) dist/doc/html/README.html

ifndef INST
INST := ""
endif

ifndef NOHTMLDOCS
NOHTMLDOCS := N
endif

ifeq ($(NOHTMLDOCS),$(filter $(NOHTMLDOCS),y Y))
$(info [INFO] Won't generate HTML documentation.)
endif

.PHONY: dirs server js api config libs docs install utest clean realclean LOC %.dep
.ONESHELL:

all:: dirs server js api config libs docs css

dirs:: $(subst src,dist,$(DIRS)); @:
server:: dirs $(subst src,dist,$(SRC_NO_COMPILE)); @:
js:: dirs $(subst src,dist,$(SRC_JS)); @:
api:: dirs $(subst src,dist,$(SRC_ENDPOINT)); @:
config:: dirs dist/common/php/config.php; @:
libs:: dirs dist/libs; @:
docs:: dirs dist/doc/rst/api_index.rst $(HTML_DOCS); @:
css:: dirs $(subst src,dist,$(SRC_SCSS:.scss=.css)); @:

# Create directory structure in 'dist/'.
$(subst src,dist,$(DIRS)):: dist%: src%
	@:
	mkdir -p $@;

# Copy over non-compiled sources.
$(subst src,dist,$(SRC_NO_COMPILE)):: dist%: src%
	@:
	cp -p $< $@;

# Copy normal PHP files to 'dist/.' and check the PHP syntax.
$(filter %.php,$(subst src,dist,$(SRC_NO_COMPILE))):: dist%: src%
	@:
	php -l $< > /dev/null;
	cp -p $< $@;

# Copy API endpoint PHP files and generate corresponding docs.
$(subst src,dist,$(SRC_ENDPOINT)):: dist%: src%
	@:
	php -l $< > /dev/null;
	cp -p $< $@;

	if [ ! "$$NOHTMLDOCS" = "y" ] && [ ! "$$NOHTMLDOCS" = "Y" ]; then
		# Generate reStructuredText documentation.
		mkdir -p dist/doc/rst;
		mkdir -p dist/doc/html;
		./build/scripts/gendoc.sh $(INST) $@ dist/doc/rst/

		# Compile rst docs into HTML.
		pandoc -f rst -t html \
			-o dist/doc/html/$(notdir $(@:.php=.html)) \
			dist/doc/rst/$(notdir $(@:.php=.rst))
	fi

dist/doc/rst/api_index.rst:: $(SRC_ENDPOINT)
	@:
	# Generate the API endpoint documentation index.
	@. build/scripts/conf.sh
	echo "LibreSignage API documentation (Ver: $$ICONF_API_VER)" > $@;
	echo '########################################################' >> $@;
	echo '' >> $@;
	echo "This document was automatically generated by the"\
		"LibreSignage build system on `date`." >> $@;
	echo '' >> $@;
	for f in $(SRC_ENDPOINT); do
		echo "\``basename $$f` </doc?doc=`basename -s '.php' $$f`>\`_" >> $@;
		echo '' >> $@;
	done

	# Compile into HTML.
	if [ ! "$$NOHTMLDOCS" = "y" ] && [ ! "$$NOHTMLDOCS" = "Y" ]; then
		pandoc -f rst -t html -o $(subst /rst/,/html/,$(@:.rst=.html)) $@;
	fi

# Copy and prepare 'config.php'.
dist/common/php/config.php:: src/common/php/config.php
	@:
	echo "[INFO] Prepare 'config.php'.";
	cp -p $< $@;
	./build/scripts/prep.sh $(INST) $@
	php -l $@ > /dev/null;

# Generate JavaScript deps.
dist/%/main.js.dep: src/%/main.js
	@:
	echo "[DEPS]: $< >> $@";
	echo "all:: `$(NPMBIN)/browserify --list $<|tr '\n' ' '`" > $@;
	echo '\n\t@$(NPMBIN)/browserify $(ROOT)$< -o $(ROOT)$(subst src,dist,$<)' >> $@;

# Compile JavaScript files.
dist/%/main.js: dist/%/main.js.dep src/%/main.js
	@:
	echo "[BROWSERIFY]: $(word 2,$^) >> $@";
	make --no-print-directory -C $(dir $<) -f $(notdir $<);

# Compile normal (non-API) documentation files.
dist/doc/html/%.html:: src/doc/rst/%.rst
	@:
	if [ ! "$$NOHTMLDOCS" = "y" ] && [ ! "$$NOHTMLDOCS" = "Y" ]; then
		mkdir -p dist/doc/html;
		pandoc -o $@ -f rst -t html $<;
	fi

# Compile README.rst
dist/doc/html/README.html:: README.rst
	@:
	if [ ! "$$NOHTMLDOCS" = "y" ] && [ ! "$$NOHTMLDOCS" = "Y" ]; then
		mkdir -p dist/doc/html;
		pandoc -o $@ -f rst -t html $<;
	fi

# Generate SCSS deps.
dist/%.scss.dep: src/%.scss
	@:
	# Don't create deps for partials.
	if [ ! "`basename '$(<)' | cut -c 1`" = "_" ]; then
		echo "[DEPS]: $< >> $@";
		echo "all:: `./build/scripts/sassdep.py $< $(SASS_IPATHS)`" > $@;
		echo "\t@sass -I $(SASS_IPATHS) $(SASSFLAGS)" \
			"$(ROOT)$< $(ROOT)$(subst src,dist,$(<:.scss=.css));" >> $@;
	fi

# Compile Sass files.
dist/%.css: dist/%.scss.dep src/%.scss
	@:
	# Don't compile partials.
	if [ ! "`basename '$(word 2,$^)' | cut -c 1`" = "_" ]; then
		echo "[SASS]: $(word 2,$^) >> $@";
		make --no-print-directory -C $(dir $<) -f $(notdir $<);
	else
		echo "[SKIP] $(word 2,$^) >> $@";
	fi

# Copy node_modules to 'dist/libs/'.
dist/libs:: node_modules
	@mkdir -p dist/libs
	@cp -Rp $</* dist/libs

install:; @./build/scripts/install.sh $(INST)

utest:; @./utests/api/main.py

clean:
	@:
	rm -rf dist;
	rm -rf `find . -type d -name '__pycache__'`;

realclean:
	@:
	rm -f build/*.iconf;
	rm -rf build/link;
	rm -rf node_modules;

# Count the lines of code in LibreSignage.
LOC:
	@:
	wc -l `find .									\
		\(											\
			-path "./dist/*" -o						\
			-path "./utests/api/.mypy_cache/*" -o	\
			-path "./node_modules/*"				\
		\) -prune 									\
		-o -name "*.py" -print						\
		-o -name "*.php" -print						\
		-o -name "*.js" -print						\
		-o -name "*.html" -print					\
		-o -name "*.css" -print						\
		-o -name "*.scss" -print					\
		-o -name "*.sh" -print						\
		-o -name "*.json" -print					\
		-o -name "*.py" -print						\
		-o -name "makefile" -print`

%:
	@:
	echo '[INFO] Ignore '$@;
