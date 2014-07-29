#!/bin/bash -eu

set +x

for A in "$@"; do 
	java -jar ~/bin/closure/compiler.jar --js ${A%%.js}.js --create_source_map ${A%%.js}-min.js.map --source_map_format=V3 --js_output_file ${A%%.js}-min.js --version
	echo >>${A%%.js}-min.js
	echo "//# sourceMappingURL=${A%%.js}-min.js.map" >>${A%%.js}-min.js
done
