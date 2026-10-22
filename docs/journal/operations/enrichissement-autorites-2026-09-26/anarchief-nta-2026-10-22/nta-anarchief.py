"""C33 — passe NTA (Nederlandse Thesaurus van Auteursnamen, KB) sur les autorités d'Anarchief sans Wikidata.
Entrée : c33/authors.json ([{id, sort_name, preferred_name, authority_type, alias, titres}]).
Règle : nom identique (nom de famille exact, prénoms compatibles) ET un titre de nos notices parmi les
titres KB de la personne (auteur ou contributeur). Un seul candidat retenu, sinon rien. Lecture seule."""
import json, re, sys, time, unicodedata, urllib.parse, urllib.request
sys.stdout.reconfigure(encoding='utf-8')
EP = 'https://data.bibliotheken.nl/sparql'
UA = 'AnarBib-C33/1.0 (rapprochement d autorites, une requete par fiche)'

def sparql(q):
    data = urllib.parse.urlencode({'query': q}).encode()
    req = urllib.request.Request(EP, data=data, headers={'Accept': 'application/sparql-results+json', 'User-Agent': UA})
    for essai in range(3):
        try:
            r = json.loads(urllib.request.urlopen(req, timeout=60).read())
            return [{k: v['value'] for k, v in b.items()} for b in r['results']['bindings']]
        except Exception as e:
            err = e; time.sleep(3)
    raise err

def norm(s):
    s = unicodedata.normalize('NFKD', (s or '').lower())
    s = ''.join(c for c in s if not unicodedata.combining(c))
    return re.sub(r'\s+', ' ', re.sub(r'[^a-z0-9 ]', ' ', s)).strip()

def esc(s): return s.replace('\\', '\\\\').replace('"', '\\"')

PART = r'(van der|van den|van de|van|de|der|den|ten|ter|te|von|du|le|la)'

def formes(a):
    """(nom de famille, prénoms) depuis sort_name « Nom, Prénoms [particule] »."""
    sn = re.sub(r',\s*Jr\.?$', '', a['sort_name']).strip()
    if ',' not in sn: return None
    fam, given = [x.strip() for x in sn.split(',', 1)]
    m = re.match(r'^(.*?)\s+' + PART + r'$', given, re.I)
    part = ''
    if m: given, part = m.group(1).strip(), m.group(2)
    fams = {fam}
    if part: fams |= {f'{part} {fam}', f'{part.capitalize()} {fam}', f'{part[0].upper()+part[1:]} {fam}'}
    return fams, given

def prenoms_ok(ours, theirs):
    a = [w for w in re.split(r'[\s.\-]+', norm(ours)) if w]
    b = [w for w in re.split(r'[\s.\-]+', norm(theirs)) if w]
    if not a or not b: return False
    for i, w in enumerate(a):
        if i >= len(b): return False
        if len(w) == 1: ok = b[i].startswith(w)
        else: ok = b[i] == w
        if not ok: return False
    return True

def titre_cle(t):
    t = norm(re.split(r'[:;.,(]| - ', t)[0])
    return t

auteurs = json.load(open('c33/authors.json', encoding='utf-8'))
res = []
for a in auteurs:
    if a['authority_type'] != 'person': continue
    f = formes(a)
    if not f:
        res.append({'id': a['id'], 'nom': a['preferred_name'], 'decision': 'sans_forme'}); continue
    fams, given = f
    vals = ' '.join(f'"{esc(x)}"' for x in fams)
    q = f'''PREFIX schema: <http://schema.org/>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT ?p ?fam ?giv ?lab ?b ?d ?nat ?same WHERE {{
  VALUES ?fam {{ {vals} }}
  ?p schema:familyName ?fam . FILTER(STRSTARTS(STR(?p), "http://data.bibliotheken.nl/id/thes/p"))
  OPTIONAL {{ ?p schema:givenName ?giv }} OPTIONAL {{ ?p rdfs:label ?lab }}
  OPTIONAL {{ ?p schema:birthDate ?b }} OPTIONAL {{ ?p schema:deathDate ?d }}
  OPTIONAL {{ ?p schema:nationality ?nat }} OPTIONAL {{ ?p schema:sameAs ?same }}
}} LIMIT 200'''
    try:
        rows = sparql(q)
    except Exception as e:
        res.append({'id': a['id'], 'nom': a['preferred_name'], 'decision': 'erreur', 'err': str(e)[:100]}); continue
    cands = {}
    for r in rows:
        c = cands.setdefault(r['p'], {'p': r['p'], 'giv': r.get('giv', ''), 'lab': r.get('lab', ''), 'b': r.get('b'), 'd': r.get('d'), 'nat': r.get('nat'), 'same': set()})
        if r.get('same'): c['same'].add(r['same'])
    compat = [c for c in cands.values() if prenoms_ok(given, c['giv'])]
    nos = {titre_cle(t) for t in (a.get('titres') or []) if len(titre_cle(t)) >= 8}
    retenus = []
    for c in compat:
        tq = f'''PREFIX schema: <http://schema.org/>
SELECT DISTINCT ?t WHERE {{ {{ ?b schema:author <{c['p']}> }} UNION {{ ?b schema:contributor <{c['p']}> }} ?b schema:name ?t }} LIMIT 400'''
        try:
            ts = [r['t'] for r in sparql(tq)]
        except Exception:
            ts = []
        leurs = {titre_cle(t) for t in ts}
        commun = sorted(n for n in nos if any(n == l or (len(n) >= 15 and (n in l or l in n)) for l in leurs))
        c['n_titres_kb'] = len(ts); c['titres_communs'] = commun
        if commun: retenus.append(c)
        time.sleep(0.5)
    out = {'id': a['id'], 'nom': a['preferred_name'], 'n_cands': len(cands), 'n_compat': len(compat)}
    if len(retenus) == 1:
        c = retenus[0]
        out.update(decision='nta_deux_signaux', nta=c['p'], label=c['lab'], b=c['b'], d=c['d'], nat=c['nat'],
                   same=sorted(c['same']), titres_communs=c['titres_communs'])
    elif len(retenus) > 1:
        out.update(decision='ambigu', cands=[(c['p'], c['lab'], c['titres_communs']) for c in retenus])
    elif len(compat) == 1:
        c = compat[0]
        out.update(decision='un_signal', nta=c['p'], label=c['lab'], b=c['b'], d=c['d'], same=sorted(c['same']), n_titres_kb=c['n_titres_kb'])
    else:
        out.update(decision='rien' if not compat else 'homonymes_sans_titre', cands=[c['lab'] for c in compat][:5])
    res.append(out)
    print(out['id'], out['nom'], '→', out['decision'], out.get('label', ''), out.get('titres_communs', ''))
    time.sleep(0.5)
json.dump(res, open('c33/nta-res.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1, default=list)
from collections import Counter
print(Counter(r['decision'] for r in res))
