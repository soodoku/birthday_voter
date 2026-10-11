.PHONY: restore fetch cells analysis manuscript paper format lint test check ci-docker clean

STATE ?= FL
EXTRACT ?= 2017

restore:
	Rscript --vanilla -e 'if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv", repos = "https://cloud.r-project.org"); renv::load(project = getwd()); renv::restore(prompt = FALSE)'

# fetch and cells need the restricted voter files; everything after runs from the committed cells.
fetch:
	Rscript scripts/00_fetch.R $(STATE) $(EXTRACT)

cells: fetch
	Rscript scripts/01_build_cells.R $(STATE) $(EXTRACT)

analysis:
	Rscript scripts/99_run_all.R

manuscript:
	cd ms && latexmk -xelatex -interaction=nonstopmode -halt-on-error main.tex

paper: analysis
	$(MAKE) manuscript

format:
	Rscript -e 'styler::style_dir("R"); styler::style_dir("scripts"); styler::style_dir("tests")'

lint:
	Rscript -e 'l <- unlist(lapply(c("R", "scripts", "tests"), lintr::lint_dir), recursive = FALSE); print(l); quit(status = as.integer(length(l) > 0))'

test: analysis
	Rscript -e 'testthat::test_dir("tests/testthat", stop_on_failure = TRUE)'

check: paper lint test

ci-docker:
	docker run --rm --platform linux/amd64 -v "$(CURDIR):/project" -w /project \
		-v r_renv_cache:/root/.cache/R/renv \
		-e RENV_CONFIG_REPOS_OVERRIDE=https://packagemanager.posit.co/cran/latest \
		rocker/verse:4.6.0 bash -c "tlmgr install latexmk fontspec booktabs float caption natbib xurl setspace adjustbox && make restore check"

clean:
	cd ms && latexmk -C main.tex
