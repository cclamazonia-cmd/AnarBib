// AnarBib — le filtre de bibliothèque du catalogue ne se fait plus doubler (13/10/2026).
// Vu par Xavier : MLEG choisie dans le catalogue, BTL et BLMF affichées, 2 344 œuvres.
// Le serveur était juste (268 notices MLEG filtrables par leur sigle). Au retour sur
// la page, le filtre mémorisé (slug) est là avant la liste des bibliothèques (qui
// donne le sigle) : une première requête SANS filtre partait, puis la bonne — et la
// première, plus lourde, répondait en dernier et écrasait l'écran. Deux gardes :
// attendre la liste quand un filtre de bibliothèque est posé, et ignorer la réponse
// d'une requête dépassée (numéro de séquence), sur tous les chemins qui écrivent.
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const page = readFileSync(path.resolve(__dirname, '../pages/public/CatalogPage.jsx'), 'utf8');
const fetchBooks = page.slice(page.indexOf('const fetchBooks = useCallback('), page.indexOf('useEffect(() => { fetchBooks(0); }, [fetchBooks]);'));

describe('le filtre de bibliothèque du catalogue, au retour sur la page', () => {
  it('attend la liste des bibliothèques avant de chercher avec un filtre de bibliothèque', () => {
    expect(page).toContain('const [libraryOptionsSettled, setLibraryOptionsSettled] = useState(false);');
    expect(page).toMatch(/setLibraryOptionsSettled\(true\);\n\s+if \(data\?\.length\) \{\n\s+setLibraryOptions\(\[/);
    expect(fetchBooks).toContain('if (libraryFilter.length > 0 && !libraryOptionsSettled) return;');
    expect(fetchBooks).toMatch(/libraryShortNames, libraryOptionsSettled, availabilityFilter/); // dépendance du useCallback
  });

  it('une réponse dépassée n’écrit plus l’écran, sur chaque chemin', () => {
    expect(page).toContain('const fetchSeq = useRef(0);');
    expect(fetchBooks).toContain('const seq = ++fetchSeq.current;');
    expect(fetchBooks).toContain('const perime = () => seq !== fetchSeq.current;');
    const gardes = (fetchBooks.match(/if \(perime\(\)\) return;/g) || []).length;
    expect(gardes).toBeGreaterThanOrEqual(5); // œuvres, liste plate, repli, liste vide, catch
    expect(fetchBooks.indexOf('if (perime()) return;')).toBeLessThan(fetchBooks.indexOf('const page = Array.isArray(data?.works)'));
    expect(fetchBooks).toContain('finally { if (!perime()) { setLoading(false); setLoadingMore(false); } }');
  });
});
