#!/bin/bash

mkdir -p esm cjs
mv index.js esm/index.js
mv index.d.ts esm/index.d.ts
for file in {test,test-*}.js ; do
	sed -i 's#./index.js#./esm/index.js#' $file
	mv -- "$file" "${file%.js}.mjs"
done
mv index.test-d.ts esm/index.test-d.ts

Replace module imports in all ts files
readarray -d '' files < <(find esm \( -name "*.js" -o -name "*.d.ts" \) -print0)
function replace_imports () {
	from=$1
	to="${2:-@esm2cjs/$from}"
	for file in "${files[@]}" ; do
		sed -i "s#'$from'#'$to'#g" "$file"
	done
}
# replace_imports "FROM" "@esm2cjs/TO"
replace_imports "aggregate-error"

PJSON=$(cat package.json | jq --tab '
	del(.type)
	| .description = .description + ". This is a fork of " + .repository + ", but with CommonJS support."
	| .repository = "esm2cjs/" + .name
	| .name |= "@esm2cjs/" + .
	| .author = { "name": "Dominic Griesel", "email": "d.griesel@gmx.net" }
	| .publishConfig = { "access": "public" }
	| .funding = "https://github.com/sponsors/AlCalzone"
	| .main = "cjs/index.js"
	| .module = "esm/index.js"
	| .files = ["cjs/", "esm/"]
	| .exports = {}
	| .exports["."].import = "./esm/index.js"
	| .exports["."].require = "./cjs/index.js"
	| .exports["./package.json"] = "./package.json"
	| .types = "esm/index.d.ts"
	| .typesVersions = {}
	| .typesVersions["*"] = {}
	| .typesVersions["*"]["esm/index.d.ts"] = ["esm/index.d.ts"]
	| .typesVersions["*"]["cjs/index.d.ts"] = ["esm/index.d.ts"]
	| .typesVersions["*"]["*"] = ["esm/*"]
	| .scripts["to-cjs"] = "esm2cjs --in esm --out cjs -t node12"
	| .xo = {ignores: ["cjs", "**/*.test-d.ts", "**/*.d.ts"]}

	| .dependencies["@esm2cjs/aggregate-error"] = .dependencies["aggregate-error"]
	| del(.dependencies["aggregate-error"])

')
echo "$PJSON" > package.json

# Update package.json -> version if upstream forgot to update it
if [[ ! -z "${TAG}" ]] ; then
	VERSION=$(echo "${TAG/v/}")
	PJSON=$(cat package.json | jq --tab --arg VERSION "$VERSION" '.version = $VERSION')
	echo "$PJSON" > package.json
fi

npm i -D @alcalzone/esm2cjs
npm run to-cjs
npm uninstall -D @alcalzone/esm2cjs

PJSON=$(cat package.json | jq --tab 'del(.scripts["to-cjs"])')
echo "$PJSON" > package.json

npm test
