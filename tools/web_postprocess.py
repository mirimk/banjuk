"""웹 빌드 후처리: claude.ai 아티팩트 호스팅(파일당 20MB, .pck 미지원)에 맞춘다.
- index.wasm 을 3조각(index.part1~3.wasm)으로 나누고, 페이지가 불러올 때 다시 합친다.
- index.pck 를 base64 로 index.pck.js 에 담고, 엔진이 index.pck 를 요청하면 그 데이터를 돌려준다.
사용: python3 tools/web_postprocess.py build/web
"""
import base64, os, sys

d = sys.argv[1] if len(sys.argv) > 1 else "build/web"
j = lambda f: os.path.join(d, f)
for f in os.listdir(d):
    if f.endswith(".import"):
        os.remove(j(f))
data = open(j("index.wasm"), "rb").read()
sz = -(-len(data) // 3)
for i in range(3):
    open(j(f"index.part{i + 1}.wasm"), "wb").write(data[i * sz:(i + 1) * sz])
pck = base64.b64encode(open(j("index.pck"), "rb").read()).decode()
open(j("index.pck.js"), "w").write("// 게임 데이터(index.pck)를 base64 로 담은 파일.\nwindow.__BANJUK_PCK = \"" + pck + "\";\n")
patch = r"""		<script>
// 엔진(index.wasm)은 3조각으로 나눠 올렸다가 합치고, 게임 데이터(index.pck)는 index.pck.js 에서 꺼낸다.
(function () {
	const origFetch = window.fetch.bind(window);
	window.fetch = async function (input, init) {
		const url = typeof input === 'string' ? input : input.url;
		if (/index\.wasm(\?.*)?$/.test(url)) {
			const parts = await Promise.all([1, 2, 3].map(function (i) {
				return origFetch(url.replace(/index\.wasm(\?.*)?$/, 'index.part' + i + '.wasm')).then(function (r) {
					if (!r.ok) { throw new Error('엔진 파일 조각 ' + i + ' 을 불러오지 못했어요 (' + r.status + ')'); }
					return r.arrayBuffer();
				});
			}));
			const blob = new Blob(parts, { type: 'application/wasm' });
			return new Response(blob, { status: 200, headers: { 'Content-Type': 'application/wasm', 'Content-Length': String(blob.size) } });
		}
		if (/index\.pck(\?.*)?$/.test(url) && window.__BANJUK_PCK) {
			const bin = atob(window.__BANJUK_PCK);
			const bytes = new Uint8Array(bin.length);
			for (let i = 0; i < bin.length; i++) { bytes[i] = bin.charCodeAt(i); }
			return new Response(bytes, { status: 200, headers: { 'Content-Type': 'application/octet-stream', 'Content-Length': String(bytes.length) } });
		}
		return origFetch(input, init);
	};
})();
		</script>
		<script src="index.pck.js"></script>
"""
html = open(j("index.html")).read()
marker = "\t\t<title>반죽 (Banjuk)</title>\n"
assert marker in html
html = html.replace(marker, marker + patch, 1).replace('<html lang="en">', '<html lang="ko">')
open(j("index.html"), "w").write(html)
os.remove(j("index.wasm"))
os.remove(j("index.pck"))
print("ok:", sorted(os.listdir(d)))
