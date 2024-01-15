all: dist/index.html

node_modules: package.json
	pnpm install

dist/index.html: node_modules $(wildcard src/*.ts)
	pnpm build

.PHONY: dev
dev:
	pnpm run dev

.PHONY: clean
clean:
	rm -rf dist

.PHONY: veryclean
veryclean:
	rm -rf node_modules
