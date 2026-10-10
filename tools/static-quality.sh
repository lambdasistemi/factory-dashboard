#!/usr/bin/env bash
# Static structure checks for the synthetic graph app.
#
# Subject is declared structure only: the compiled build log, module
# import graph, FFI pairing and dependency inventory. No claim about
# behaviour or privacy is made here; those are proven by the decoder
# suites and the browser checks.
#
# Usage: static-quality.sh <path-to-app-build-log>
set -euo pipefail

build_log="$1"

fail() { printf 'static-quality: %s\n' "$1" >&2; exit 1; }

# --- strict compiler warning policy --------------------------------------
test -s "$build_log" || fail "missing build log from the app build"
grep -q 'Build succeeded' "$build_log" || fail "build log shows no successful compile"
if grep -E '^\[WARNING' "$build_log"; then
  fail "compiler warnings are present; the warning policy is strict"
fi

# --- module responsibility and dependency direction ----------------------
# One rule per module: <file>|<allowed-import-regex>
layer_rules=(
  'src/Factory/Domain.purs|^(Prelude|Data\.|Control\.)'
  'src/Factory/Decode.purs|^(Prelude|Data\.|Control\.|Foreign\.|Factory\.Domain)'
  'src/Factory/ViewState.purs|^(Prelude|Data\.|Control\.|Factory\.Domain)'
  'src/Factory/Layout.purs|^(Prelude|Data\.|Control\.|Factory\.Domain)'
  'src/Factory/Scenarios.purs|^(Prelude|Data\.|Factory\.Fixtures)'
  'src/Factory/Platform.purs|^(Prelude|Data\.|Effect|Web\.)'
  'src/Factory/View.purs|^(Prelude|Data\.|Control\.|Effect|Halogen|Web\.|Factory\.)'
  'src/Main.purs|^(Prelude|Data\.|Effect|Halogen|Web\.|Factory\.)'
)
for rule in "${layer_rules[@]}"; do
  file="${rule%%|*}"
  pattern="${rule#*|}"
  test -f "$file" || fail "expected module $file is missing"
  while IFS= read -r line; do
    module="$(printf '%s' "$line" | awk '{print $2}')"
    if ! printf '%s' "$module" | grep -qE "$pattern"; then
      fail "$file imports $module, outside its allowed dependency direction"
    fi
  done < <(grep -E '^import ' "$file" || true)
done
echo "layer direction: ok"

# --- typed FFI inventory: pairs, exports, bounded count -------------------
js_count=$(find src -name '*.js' -type f | wc -l)
if [ "$js_count" -lt 1 ]; then fail "no FFI files found; fixture loading needs its pair"; fi
if [ "$js_count" -gt 4 ]; then fail "FFI surface grew to $js_count files; keep it minimal"; fi
while IFS= read -r js; do
  purs="${js%.js}.purs"
  test -f "$purs" || fail "$js has no PureScript sibling"
  while IFS= read -r name; do
    grep -qE "export (const|function) $name" "$js" \
      || fail "$purs foreign-imports $name but $js does not export it"
  done < <(grep -E '^foreign import ' "$purs" | awk '{print $3}' || true)
done < <(find src -name '*.js' -type f)
echo "ffi inventory: $js_count file(s), all typed and paired"

# --- dependency inventory --------------------------------------------------
command -v jq >/dev/null || fail "jq missing"
runtime_deps=$(jq '.dependencies // {} | length' package.json)
[ "$runtime_deps" -eq 0 ] || fail "runtime npm budget is zero; found $runtime_deps"
dev_count=$(jq '.devDependencies | length' package.json)
[ "$dev_count" -eq 1 ] || fail "exactly one pinned dev dependency is expected"
jq -e '.devDependencies."@playwright/test" == "1.54.1"' package.json >/dev/null \
  || fail "Playwright runner must stay pinned to the nixpkgs browser build"
test -f spago.lock || fail "spago.lock must be committed"
allowed_deps='prelude effect aff maybe either arrays strings tuples integers partial nullable foldable-traversable ordered-collections foreign-object argonaut-core argonaut halogen web-dom web-events web-uievents halogen-subscriptions spec spec-node console'
while IFS= read -r dep; do
  [ -z "$dep" ] && continue
  case " $allowed_deps " in
    *" $dep "*) ;;
    *) fail "dependency $dep is outside the approved direct set" ;;
  esac
done < <(awk '/^  dependencies:/{f=1;next} /^  [a-z]/{f=0} f{gsub(/^ +- /,"");print}' spago.yaml)
echo "dependency inventory: ok"
