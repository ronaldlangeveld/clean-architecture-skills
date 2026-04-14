#!/usr/bin/env bash
# Validate every skill in skills/ against the Agent Skills spec.
# Checks:
#   - SKILL.md exists
#   - Required frontmatter fields (name, description)
#   - name matches directory name
#   - name follows naming rules (lowercase, digits, hyphens; 1-64 chars; no leading/trailing/consecutive hyphens)
#   - description length (1-1024 chars)
#   - SKILL.md body is <= 500 lines
#   - metadata.version is present

set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$ROOT/skills"
errors=0
checked=0

if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "ERROR: $SKILLS_DIR does not exist"
  exit 1
fi

fail() {
  echo "  [FAIL] $1"
  errors=$((errors + 1))
}

pass() {
  echo "  [OK]   $1"
}

for skill_dir in "$SKILLS_DIR"/*/; do
  [[ -d "$skill_dir" ]] || continue
  dir_name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"
  checked=$((checked + 1))

  echo ""
  echo "Validating: $dir_name"

  if [[ ! -f "$skill_file" ]]; then
    fail "SKILL.md missing"
    continue
  fi
  pass "SKILL.md exists"

  # Extract frontmatter (between the first two '---' lines)
  frontmatter="$(awk '/^---$/{c++; next} c==1' "$skill_file")"

  if [[ -z "$frontmatter" ]]; then
    fail "frontmatter missing or malformed"
    continue
  fi

  name="$(echo "$frontmatter" | awk -F': *' '/^name:/ {print $2; exit}' | tr -d '"' | tr -d "'")"
  description="$(echo "$frontmatter" | awk '/^description:/{sub(/^description: *"?/,""); print; exit}' | sed 's/"$//')"
  version_line="$(echo "$frontmatter" | awk '/^  version:/{print; exit}')"

  # Name checks
  if [[ -z "$name" ]]; then
    fail "name field missing"
  elif [[ "$name" != "$dir_name" ]]; then
    fail "name ($name) does not match directory ($dir_name)"
  elif [[ ! "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    fail "name ($name) violates naming rules (lowercase, digits, hyphens; no leading/trailing/consecutive hyphens)"
  elif (( ${#name} < 1 || ${#name} > 64 )); then
    fail "name length (${#name}) out of range 1-64"
  else
    pass "name valid"
  fi

  # Description checks
  if [[ -z "$description" ]]; then
    fail "description field missing"
  elif (( ${#description} < 1 || ${#description} > 1024 )); then
    fail "description length (${#description}) out of range 1-1024"
  else
    pass "description valid (${#description} chars)"
  fi

  # Version check
  if [[ -z "$version_line" ]]; then
    fail "metadata.version missing"
  else
    pass "metadata.version present"
  fi

  # Body line count
  body_lines="$(awk '/^---$/{c++; next} c>=2' "$skill_file" | wc -l | tr -d ' ')"
  if (( body_lines > 500 )); then
    fail "SKILL.md body is $body_lines lines (max 500)"
  else
    pass "body length ok ($body_lines lines)"
  fi
done

echo ""
echo "---"
echo "Checked $checked skill(s), $errors error(s)"

if (( errors > 0 )); then
  exit 1
fi
