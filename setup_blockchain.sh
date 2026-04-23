#!/bin/bash
# =============================================================================
# setup_blockchain.sh
# Configure automatiquement le réseau MultiChain entre tous les noeuds Docker
#
# Étapes exécutées (conformément au guide) :
#   1.  Détection automatique des conteneurs par mot-clé de rôle
#   2.  Récupération de l'adresse de connexion via les logs Docker du producteur
#   3.  Connexion de chaque noeud à la blockchain
#   4.  Extraction des hash MultiChain de chaque noeud
#   5.  Grant connect depuis le producteur
#   6.  Reconnexion de tous les noeuds en mode daemon
#   7.  Création des streams streamA et streamB (read,write restreints)
#   8.  Attribution des permissions read/write par stream et par noeud
#   9.  Abonnement de chaque noeud à ses streams autorisés
#   10. Tableau récapitulatif conteneur → hash → permissions
#
# Usage : bash setup_blockchain.sh
# Prérequis : docker compose up déjà exécuté, noeud producteur actif
# =============================================================================

# --- Couleurs terminal (toutes vers stderr pour ne pas polluer les captures) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Toutes les fonctions de log écrivent sur stderr
# → elles n'interfèrent pas avec les $() de capture de valeurs
log_info()  { echo -e "  ${CYAN}[INFO]${NC}   $1" >&2; }
log_ok()    { echo -e "  ${GREEN}[  OK ]${NC}  $1" >&2; }
log_warn()  { echo -e "  ${YELLOW}[ WARN]${NC}  $1" >&2; }
log_error() { echo -e "  ${RED}[ERREUR]${NC} $1" >&2; }
log_step()  { echo "" >&2; echo -e "${BOLD}$1${NC}" >&2; echo "  $(echo "$1" | sed 's/./─/g')" >&2; }

# =============================================================================
# ÉTAPE 0 — Détection automatique des conteneurs par mot-clé
# =============================================================================

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     CONFIGURATION AUTOMATIQUE DU RÉSEAU MULTICHAIN          ║"
echo "╚══════════════════════════════════════════════════════════════╝"

log_step "[ ÉTAPE 0 ] Détection des conteneurs Docker"

echo "" >&2
echo "  Conteneurs actifs :" >&2
echo "" >&2
docker ps --format "  • {{.Names}}" 2>/dev/null >&2
echo "" >&2

# --- Détection par mot-clé ---
# Logs → stderr  |  valeur de retour → stdout (propre pour $())
detect_container() {
  local KEYWORD=$1
  local LABEL=$2

  local FOUND
  FOUND=$(docker ps --format "{{.Names}}" \
    | grep -iE "$KEYWORD" \
    | head -1)

  if [ -z "$FOUND" ]; then
    log_warn "Aucun conteneur trouvé avec le mot-clé '$KEYWORD' pour $LABEL."
    read -p "  Entrez manuellement le nom du conteneur $LABEL : " FOUND >&2
  else
    read -p "  $LABEL détecté → '$FOUND' — Confirmer ? (Entrée = oui, ou nouveau nom) : " OVERRIDE
    [ -n "$OVERRIDE" ] && FOUND="$OVERRIDE"
  fi

  if ! docker ps --format "{{.Names}}" | grep -q "^${FOUND}$"; then
    log_error "Conteneur '$FOUND' introuvable ou non démarré."
    exit 1
  fi

  log_ok "$LABEL → $FOUND"
  echo "$FOUND"   # ← seule sortie sur stdout, capturée proprement par $()
}

CONT_PROD=$(detect_container   "producteur"                                   "Producteur")
CONT_TRANS=$(detect_container  "transporteur"                                 "Transporteur")
CONT_DIST_A=$(detect_container "distributeur-a|distributeur_a|distrib-a"      "Distributeur A")
CONT_DIST_B=$(detect_container "distributeur-b|distributeur_b|distrib-b"      "Distributeur B")

echo "" >&2
read -p "  Nom de la blockchain  (ex: org_blockchain) : " CHAIN
echo "" >&2

# =============================================================================
# ÉTAPE 1 — Saisie de l'adresse de connexion du noeud producteur
# =============================================================================

log_step "[ ÉTAPE 1 ] Adresse de connexion du noeud producteur"

echo "" >&2
echo "  L'adresse IP et le port sont affichés dans les logs du producteur," >&2
echo "  sous la forme : multichaind ${CHAIN}@172.24.0.3:6297" >&2
echo "  Consultez-les avec : docker logs $CONT_PROD" >&2
echo "" >&2

read -p "  IP du noeud producteur    (ex: 172.24.0.3) : " PROD_IP
read -p "  Port blockchain           (ex: 6297)        : " PROD_PORT

NODE_ADDRESS_PROD="${CHAIN}@${PROD_IP}:${PROD_PORT}"

log_ok "Adresse de connexion : $NODE_ADDRESS_PROD"

# =============================================================================
# ÉTAPE 2 — Connexion des noeuds + extraction des hash MultiChain
# =============================================================================

log_step "[ ÉTAPE 2 ] Connexion des noeuds à la blockchain et extraction des hash"

extract_hash() {
  local CONTENEUR=$1
  local LABEL=$2

  log_info "Connexion de $LABEL ($CONTENEUR)..."

  OUTPUT=$(docker exec "$CONTENEUR" \
    multichaind "${NODE_ADDRESS_PROD}" 2>&1)

  # Extraire le hash depuis la ligne "grant [HASH] connect"
  local HASH
  HASH=$(echo "$OUTPUT" \
    | grep "grant" \
    | grep "connect" \
    | head -1 \
    | awk '{for(i=1;i<=NF;i++) if($i=="grant") print $(i+1)}')

  # Fallback regex sur adresse Base58
  if [ -z "$HASH" ]; then
    HASH=$(echo "$OUTPUT" \
      | grep -oE '[1-9A-HJ-NP-Za-km-z]{25,34}' \
      | head -1)
  fi

  if [ -z "$HASH" ]; then
    log_warn "$LABEL : hash non extrait automatiquement."
    read -p "  Entrez manuellement le hash MultiChain de $LABEL : " HASH >&2
  else
    log_ok "$LABEL → $HASH"
  fi

  echo "$HASH"
}

HASH_TRANS=$(extract_hash  "$CONT_TRANS"  "Transporteur")
HASH_DIST_A=$(extract_hash "$CONT_DIST_A" "Distributeur A")
HASH_DIST_B=$(extract_hash "$CONT_DIST_B" "Distributeur B")

# Hash du producteur via listaddresses
HASH_PROD=$(docker exec "$CONT_PROD" \
  multichain-cli "$CHAIN" listaddresses 2>/dev/null \
  | grep '"address"' \
  | head -1 \
  | sed 's/.*"address"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

log_info "Hash producteur : $HASH_PROD"

# =============================================================================
# ÉTAPE 3 — Grant connect depuis le producteur
# =============================================================================

log_step "[ ÉTAPE 3 ] Grant connect pour chaque noeud (depuis le producteur)"

grant_connect() {
  local HASH=$1
  local LABEL=$2

  RESULT=$(docker exec "$CONT_PROD" \
    multichain-cli "$CHAIN" grant "$HASH" connect 2>&1)

  if echo "$RESULT" | grep -q '"method":"grant"'; then
    log_ok "connect → $LABEL ($HASH)"
  else
    log_warn "Résultat inattendu pour $LABEL : $RESULT"
  fi
}

grant_connect "$HASH_TRANS"  "Transporteur"
grant_connect "$HASH_DIST_A" "Distributeur A"
grant_connect "$HASH_DIST_B" "Distributeur B"

sleep 2

# =============================================================================
# ÉTAPE 4 — Reconnexion des noeuds en mode daemon
# =============================================================================

log_step "[ ÉTAPE 4 ] Reconnexion des noeuds en mode daemon"

reconnect_daemon() {
  local CONTENEUR=$1
  local LABEL=$2

  docker exec -d "$CONTENEUR" multichaind "$CHAIN" -daemon 2>/dev/null
  sleep 2
  log_ok "$LABEL reconnecté en daemon"
}

reconnect_daemon "$CONT_TRANS"  "Transporteur"
reconnect_daemon "$CONT_DIST_A" "Distributeur A"
reconnect_daemon "$CONT_DIST_B" "Distributeur B"

sleep 3

# =============================================================================
# ÉTAPE 5 — Création des streams streamA et streamB
# =============================================================================

log_step "[ ÉTAPE 5 ] Création des streams streamA et streamB"

create_stream() {
  local STREAM=$1

  RESULT=$(docker exec "$CONT_PROD" \
    multichain-cli "$CHAIN" create stream "$STREAM" \
    '{"restrict":"read,write"}' 2>&1)

  if echo "$RESULT" | grep -q '"method":"create"'; then
    log_ok "Stream '$STREAM' créé avec restrict:read,write"
  else
    log_warn "Stream '$STREAM' : $RESULT"
  fi
}

create_stream "streamA"
create_stream "streamB"

sleep 2

# =============================================================================
# ÉTAPE 6 — Attribution des permissions par stream
#
# Table des permissions (guide p.5) :
#   Noeud            streamA        streamB
#   Producteur       read/write     read/write
#   Transporteur     read/write     read/write
#   Distributeur A   read/write     NON/NON
#   Distributeur B   NON/NON        read/write
# =============================================================================

log_step "[ ÉTAPE 6 ] Attribution des permissions read/write par stream"

grant_stream() {
  local HASH=$1
  local STREAM=$2
  local LABEL=$3

  # Permission générale send (prérequis obligatoire)
  docker exec "$CONT_PROD" multichain-cli "$CHAIN" \
    grant "$HASH" send > /dev/null 2>&1

  RESULT_R=$(docker exec "$CONT_PROD" \
    multichain-cli "$CHAIN" grant "$HASH" "${STREAM}.read" 2>&1)

  RESULT_W=$(docker exec "$CONT_PROD" \
    multichain-cli "$CHAIN" grant "$HASH" "${STREAM}.write" 2>&1)

  if echo "$RESULT_R" | grep -q '"method"' && \
     echo "$RESULT_W" | grep -q '"method"'; then
    log_ok "$LABEL → $STREAM : read ✓  write ✓"
  else
    log_warn "$LABEL → $STREAM : résultat inattendu"
    log_warn "  read  : $RESULT_R"
    log_warn "  write : $RESULT_W"
  fi
}

log_info "Permissions streamA..." >&2
grant_stream "$HASH_PROD"   "streamA" "Producteur"
grant_stream "$HASH_TRANS"  "streamA" "Transporteur"
grant_stream "$HASH_DIST_A" "streamA" "Distributeur A"

log_info "Permissions streamB..." >&2
grant_stream "$HASH_PROD"   "streamB" "Producteur"
grant_stream "$HASH_TRANS"  "streamB" "Transporteur"
grant_stream "$HASH_DIST_B" "streamB" "Distributeur B"

sleep 2

# =============================================================================
# ÉTAPE 7 — Abonnement de chaque noeud à ses streams autorisés
# =============================================================================

log_step "[ ÉTAPE 7 ] Abonnement des noeuds à leurs streams"

subscribe_stream() {
  local CONTENEUR=$1
  local STREAM=$2
  local LABEL=$3

  RESULT=$(docker exec "$CONTENEUR" \
    multichain-cli "$CHAIN" subscribe "$STREAM" 2>&1)

  if echo "$RESULT" | grep -qiE '"method":"subscribe"|null'; then
    log_ok "$LABEL abonné à $STREAM"
  else
    log_warn "$LABEL → subscribe $STREAM : $RESULT"
  fi
}

subscribe_stream "$CONT_PROD"   "streamA" "Producteur"
subscribe_stream "$CONT_PROD"   "streamB" "Producteur"
subscribe_stream "$CONT_TRANS"  "streamA" "Transporteur"
subscribe_stream "$CONT_TRANS"  "streamB" "Transporteur"
subscribe_stream "$CONT_DIST_A" "streamA" "Distributeur A"
subscribe_stream "$CONT_DIST_B" "streamB" "Distributeur B"

# =============================================================================
# ÉTAPE 8 — Tableau récapitulatif
# =============================================================================

log_step "[ ÉTAPE 8 ] Récapitulatif de la configuration"

C1=34
C2=40
C3=14
C4=14

hline() {
  local L=$1 M=$2 R=$3
  printf "  ${L}"
  printf '─%.0s' $(seq 1 $C1)
  printf "${M}"
  printf '─%.0s' $(seq 1 $C2)
  printf "${M}"
  printf '─%.0s' $(seq 1 $C3)
  printf "${M}"
  printf '─%.0s' $(seq 1 $C4)
  printf "${R}\n"
}

pad() { printf "%-${1}s" "$2"; }

print_row() {
  printf "  │ $(pad $((C1-2)) "$1")│ $(pad $((C2-2)) "$2")│ $(pad $((C3-2)) "$3")│ $(pad $((C4-2)) "$4")│\n"
}

echo ""
hline "┌" "┬" "┐"
print_row "Conteneur Docker" "Hash MultiChain" "streamA" "streamB"
hline "├" "┼" "┤"
print_row "$CONT_PROD"   "$HASH_PROD"   "read/write" "read/write"
hline "├" "┼" "┤"
print_row "$CONT_TRANS"  "$HASH_TRANS"  "read/write" "read/write"
hline "├" "┼" "┤"
print_row "$CONT_DIST_A" "$HASH_DIST_A" "read/write" "aucune"
hline "├" "┼" "┤"
print_row "$CONT_DIST_B" "$HASH_DIST_B" "aucune"     "read/write"
hline "└" "┴" "┘"

echo ""
echo "  Blockchain  : $CHAIN"
echo "  Noeud seed  : $NODE_ADDRESS_PROD"
echo ""
echo -e "  ${GREEN}${BOLD}Configuration terminée avec succès.${NC}"
echo ""
echo "  Scripts disponibles dans : /root/chainscripts/"
echo ""
