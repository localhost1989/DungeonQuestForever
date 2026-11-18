# Английская версия аддона. Три шага, все из папки dungeon-quest-handoff:
#   python3 make-locale.py extract   — выписать русские строки из кода в locale/strings.json и куски для перевода
#   python3 make-locale.py wrap      — обернуть русские строки в коде вызовом L"..." (один раз; повторно не оборачивает)
#   python3 make-locale.py build     — собрать переводы из locale/en.json (русская строка -> английская) в таблицу внутри Core.lua
# Новая русская строка в коде: wrap, затем build покажет «НЕТ ПЕРЕВОДА», дописать её в locale/en.json, снова build.
import io, json, os, re, sys

SRC = "../ForeverDungeonPrep"
FILES = ["Core", "Plan", "SecretCatalog", "PartyTips", "BossRoute", "Ways", "Secrets", "Journal", "Book", "Gear"]
CYR = re.compile("[А-Яа-яЁё]")

def tokens(text):
    """Yield (kind, start, end) for strings and comments of a Lua source."""
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if text.startswith("--", i):
            m = re.match(r"--\[(=*)\[", text[i:])
            if m:
                close = "]" + m.group(1) + "]"
                j = text.find(close, i)
                j = n if j < 0 else j + len(close)
            else:
                j = text.find("\n", i)
                j = n if j < 0 else j
            yield ("comment", i, j)
            i = j
        elif c in "\"'":
            j = i + 1
            while j < n and text[j] != c:
                j += 2 if text[j] == "\\" else 1
            yield ("string", i, j + 1)
            i = j + 1
        elif c == "[" and re.match(r"\[(=*)\[", text[i:]):
            m = re.match(r"\[(=*)\[", text[i:])
            close = "]" + m.group(1) + "]"
            j = text.find(close, i)
            j = n if j < 0 else j + len(close)
            yield ("long", i, j)
            i = j
        else:
            i += 1

def russian(name):
    text = io.open("%s/%s.lua" % (SRC, name), encoding="utf-8").read()
    skip = (0, 0)
    a, b = text.find("-- BEGIN LOOT"), text.find("-- END LOOT")
    if a >= 0 and b >= 0: skip = (a, b)
    c, d = text.find("-- LOCALE BEGIN"), text.find("-- LOCALE END")
    # The places inside the dungeons carry both tongues themselves (make-inside-lua.py).
    g, h = text.find("-- BEGIN INSIDE SPOTS"), text.find("-- END INSIDE SPOTS")
    out = []
    for kind, s, e in tokens(text):
        if kind != "string" or (skip[0] <= s < skip[1]) or (c >= 0 and c <= s < d) or (g >= 0 and g <= s < h): continue
        if text[s] != '"' or not CYR.search(text[s:e]): continue
        out.append((s, e))
    return text, out

def line_of(text, pos):
    a = text.rfind("\n", 0, pos) + 1
    b = text.find("\n", pos)
    return text[a:(len(text) if b < 0 else b)].strip()

def extract():
    seen, order = {}, []
    for name in FILES:
        text, found = russian(name)
        for s, e in found:
            raw = text[s + 1:e - 1]
            if raw not in seen:
                seen[raw] = {"id": len(order) + 1, "file": name, "raw": raw, "context": line_of(text, s)[:260]}
                order.append(seen[raw])
    json.dump(order, io.open("locale/strings.json", "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    groups = {"A": ["SecretCatalog"], "C": ["Ways"], "D": ["Journal"], "E": ["Core", "Plan", "PartyTips", "BossRoute", "Secrets", "Book"]}
    for key, names in groups.items():
        items = [o for o in order if o["file"] in names]
        parts = [items]
        if key == "A":
            half = len(items) // 2
            parts = [items[:half], items[half:]]
        for k, part in enumerate(parts):
            label = key + (str(k + 1) if len(parts) > 1 else "")
            with io.open("locale/ru-%s.txt" % label, "w", encoding="utf-8") as f:
                for o in part:
                    f.write("ID %d\nRU %s\nIN %s\n\n" % (o["id"], o["raw"], o["context"]))
            print(label, len(part), sum(len(o["raw"]) for o in part))
    print("unique", len(order))

def wrap():
    for name in FILES:
        text, found = russian(name)
        done = 0
        for s, e in reversed(found):
            before = text[:s].rstrip(" \t")
            prev = before[-1:] if before else ""
            if text[s - 1:s] == "L" and not (text[s - 2:s - 1].isalnum() or text[s - 2:s - 1] == "_"): continue
            lit = text[s:e]
            # A literal passed to a function without brackets keeps its meaning only in brackets of its own.
            if prev and (prev.isalnum() or prev in "_)]\"'"):
                text = text[:s] + "(L" + lit + ")" + text[e:]
            else:
                text = text[:s] + "L" + lit + text[e:]
            done += 1
        if "local L = " not in text and "-- LOCALE BEGIN" not in text:
            head = "local _, P = ...\n"
            assert text.startswith(head), name
            if name == "Core":
                text = head + CORE_L + text[len(head):]
            else:
                text = head + "local L = P.L or function(s) return s end\n" + text[len(head):]
        io.open("%s/%s.lua" % (SRC, name), "w", encoding="utf-8").write(text)
        print(name, done)

CORE_L = '''
-- The words of the addon are written in Russian, the language of its first owner. For
-- every other client they are said in English: L"..." gives the English of a Russian
-- line from the table below (made by dungeon-quest-handoff/make-locale.py; not edited by
-- hand), or the line itself where the client is Russian or the table has nothing.
-- LOCALE BEGIN
local EN = {}
-- LOCALE END
local russianClient = (GetLocale and GetLocale() or "enUS") == "ruRU"
P.LMissing = {}
local function L(s)
    if russianClient then return s end
    local said = EN[s]
    if said == nil then P.LMissing[s] = true return s end
    return said
end
P.L = L
function P.Language(code)
    -- For the tests: say the words as another client would.
    russianClient = code == "ruRU"
end
'''

def build():
    """The English of every Russian line in the code, from locale/en.json (русская строка -> английская)."""
    store = json.load(io.open("locale/en.json", encoding="utf-8"))
    seen, lines, missing, odd = set(), [], [], []
    for name in FILES:
        text, found = russian(name)
        for s, e in found:
            ru = text[s + 1:e - 1]
            if ru in seen: continue
            seen.add(ru)
            en = store.get(ru)
            if en is None:
                missing.append(ru); continue
            for what, pat in (("%-формат", r"%[-0-9.]*[dsf]"), ("цвет", r"\|c[0-9a-fA-F]{8}"), ("сброс цвета", r"\|r"), ("перевод строки", r"\\n")):
                if len(re.findall(pat, ru)) != len(re.findall(pat, en)): odd.append((ru[:40], what))
            if (ru[:1] == " ") != (en[:1] == " ") or (ru[-1:] == " ") != (en[-1:] == " "): odd.append((ru[:40], "пробел по краям"))
            lines.append('    ["%s"] = "%s",' % (ru, en))
    path = SRC + "/Core.lua"
    text = io.open(path, encoding="utf-8").read()
    new, n = re.subn(r"(-- LOCALE BEGIN\n).*?(-- LOCALE END)", lambda m: m.group(1) + "local EN = {\n" + "\n".join(lines) + "\n}\n" + m.group(2), text, flags=re.S)
    assert n == 1
    io.open(path, "w", encoding="utf-8").write(new)
    print("written", len(lines), "of", len(seen), "| без перевода:", len(missing), "| странных:", len(odd), odd[:20])
    for ru in missing: print("  НЕТ ПЕРЕВОДА:", ru)

if __name__ == "__main__":
    {"extract": extract, "wrap": wrap, "build": build}[sys.argv[1]]()
