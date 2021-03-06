# Usage
#
# make [syllabus]		# generate out/syllabus.pdf
# make schedule			# generate out/schedule.html and copy to clipboard
# make out/booklist.pdf		# generate out/booklist.pdf
# make clean			# remove intermediate files
# make reallyclean		# remove intermediate and output files

## ---- user config ----

# base for name of output .tex and .pdf files
syllabus := syllabus
# base for name of output .html file
web := schedule

# list of other markdown files to turn into standalone PDFs
other_mds := booklist.md

# markdown files compiled into $(web).html
html_md := schedule-page.md 4schedule.md

# other files to exclude from the syllabus
EXCLUDE := README.md schedule-page.md $(other_mds)

# list of markdown files (in order) for the syllabus sections
# use the default only if all .md files in alphabetical order works for you
syllabus_md := $(filter-out $(EXCLUDE),$(wildcard *.md))
# syllabus configuration (normally just the one yaml file)
syllabus_yaml := $(wildcard *.yaml)

# Set to anything non-empty to suppress most of latex's messaging. To diagnose
# LaTeX errors, you may want to do `make latex_quiet=""` to get verbose output
latex_quiet := true

# Set to anything non-empty to reprocess the TeX file every time we make the PDF.
# Otherwise the former will be regenerated only when the source markdown
# changes; in that case, if you change other dependencies (e.g. the
# bibliography), use the -B option to make in order to force regeneration.
# always_latexmk := true
always_latexmk := 

# Set to anything non-empty to use xelatex rather than pdflatex. I always do
# this in order to use system fonts and better Unicode support. pdflatex is
# faster, and there are some packages with which xelatex is incompatible.
xelatex := true

# Extra options to pandoc (e.g. "-H mypreamble.tex")
PANDOC_OPTIONS := --biblatex

## ---- special external files ----

# Normally this does not need to be changed:
# works if the template is local or in ~/.pandoc/templates
SYLLABUS_TMPL := memoir-syllabus.latex
HTML_TMPL := bib4ht.latex

# clean4ht can come from the local directory or be installed somewhere in the PATH
CLEAN4HT = $(shell which clean4ht || echo ./clean4ht)

## ---- subdirectories (normally, no need to change) ----

# temporary file subdirectory; will be removed after every latex run
temp_dir := tmp

# name of output directory for .tex and .pdf files
out_dir := out

## ---- commands ----

# Change these only to really change the behavior of the whole setup

PANDOC := pandoc $(if $(xelatex),--latex-engine xelatex) \
    $(PANDOC_OPTIONS)

LATEXMK := latexmk $(if $(xelatex),-xelatex,-pdflatex="pdflatex %O %S") \
    -pdf -dvi- -ps- $(if $(latex_quiet),-silent,-verbose) \
    -outdir=$(temp_dir)

## ---- build rules ----

syllabus_tex := $(out_dir)/$(syllabus).tex
syllabus_pdf := $(out_dir)/$(syllabus).pdf

texs := $(patsubst %.md,$(out_dir)/%.tex,$(other_mds))
pdfs := $(patsubst %.md,$(out_dir)/%.pdf,$(other_mds)) $(syllabus_pdf)

$(syllabus_tex): $(syllabus_yaml) $(syllabus_md)
	mkdir -p $(dir $@)
	$(PANDOC) --template=$(SYLLABUS_TMPL) -o $@ $^

$(texs): $(out_dir)/%.tex: %.md
	mkdir -p $(dir $@)
	$(PANDOC) --template=$(SYLLABUS_TMPL) -o $@ $<

phony_pdfs := $(if $(always_latexmk),$(pdfs))

$(syllabus): $(syllabus_pdf)

.PHONY: $(phony_pdfs) clean reallyclean all $(web) $(syllabus)

$(pdfs): %.pdf: %.tex
	mkdir -p $(dir $@)
	rm -rf $(dir $@)$(temp_dir)
	cd $(dir $<); $(LATEXMK) $(notdir $<)
	mv $(dir $<)$(temp_dir)/$(notdir $@) $@
	rm -r $(dir $<)$(temp_dir)

html := $(out_dir)/$(web).html
html_tex := $(patsubst %.html,%.tex,$(html))

$(html_tex): $(html_md) $(bib)
	mkdir -p $(dir $@)
	$(PANDOC) --template=$(HTML_TMPL) $(html_md) -o $@

$(html): $(html_tex)
	rm -rf $(dir $@)$(temp_dir)
	mkdir -p $(out_dir)/$(temp_dir)
	cp -f $< $(dir $@)$(temp_dir)
	cd $(dir $@)$(temp_dir); latexmk -pdf- -ps- -dvi $(notdir $<)
	cd $(dir $@)$(temp_dir); htlatex $(notdir $<) \
	    ../../bib4ht.cfg " -cunihtf -utf8" "-cvalidate" \
	    $(if $(latex_quiet),> /dev/null)
	pandoc --filter $(CLEAN4HT) $(dir $@)$(temp_dir)/$(notdir $@) -o $@
	rm -r $(dir $@)$(temp_dir)

$(web): $(html)
	pbcopy < $<

# clean up everything except final pdf
clean:
	rm -rf $(out_dir)/$(temp_dir)
	rm -f $(texs) $(syllabus_tex) $(html_tex)

# clean up everything including pdfs
reallyclean: clean
	rm -f $(pdfs) $(html)
	-rmdir $(out_dir)

all: $(pdfs) $(html)

.DEFAULT_GOAL := $(syllabus_pdf)
