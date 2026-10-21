#!/bin/sh
set -e
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
JS=build/web/index.js
sed -i '' 's/if (!Features.isSecureContext()) {/if (false \&\& !Features.isSecureContext()) {/' "$JS"
sed -i '' 's/GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet.addModule(path)/GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet?ctx.audioWorklet.addModule(path):Promise.resolve()/' "$JS"
sed -i '' 's/if(this.isCanceled){return}this._source.connect(this.getPositionWorklet())/if(this.isCanceled){return}if(GodotAudio.ctx.audioWorklet)this._source.connect(this.getPositionWorklet())/' "$JS"
for p in 'false && !Features.isSecureContext()' 'ctx.audioWorklet?ctx.audioWorklet.addModule(path)' 'if(GodotAudio.ctx.audioWorklet)this._source.connect'; do
	grep -qF "$p" "$JS" || { echo "Falhou ao ajustar index.js para HTTP: $p" >&2; exit 1; }
done
echo "Pronto: build/web/ (IP do Mac: $(ipconfig getifaddr en0 2>/dev/null || echo '?'))"
