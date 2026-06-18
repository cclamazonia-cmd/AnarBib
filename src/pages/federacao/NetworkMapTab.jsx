import CartographyMap from './CartographyMap';

// Onglet « Annuaire » de la page Fédération (interne, authentifié·e) : carte du
// réseau lue depuis la table via api.cartography_network_v1 (toutes les fiches).
// Le rendu Leaflet + filtres + popups 10 locales vit dans CartographyMap (partagé
// avec la carte publique /cartografia).
export default function NetworkMapTab() {
  return <CartographyMap viewName="cartography_network_v1" />;
}
