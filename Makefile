VENV := .venv
PYTHON := python3
PIP := $(VENV)/bin/pip
MKDOCS := $(VENV)/bin/mkdocs

.PHONY: docs-setup docs-serve docs-build

docs-setup: $(VENV)/bin/mkdocs

$(VENV)/bin/mkdocs: requirements.txt
	$(PYTHON) -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt

docs-serve: docs-setup
	$(MKDOCS) serve

docs-build: docs-setup
	$(MKDOCS) build
