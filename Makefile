.PHONY: build test clean

build:
	python -m retail build

test:
	pytest tests/ -q

clean:
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null; \
	find . -name "*.pyc" -delete 2>/dev/null; rm -rf .pytest_cache
