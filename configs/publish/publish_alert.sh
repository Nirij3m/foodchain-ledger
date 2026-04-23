#!/bin/bash
# =============================================================================
# publish_alert.sh
# Publie une alerte ou un rappel de lot sur la blockchain MultiChain
# Usage : bash publish_alert.sh
# =============================================================================

TODAY=$(date -u +%Y-%m-%d)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo ""
echo "=============================================="
echo "  PUBLICATION — ALERTE / RAPPEL DE LOT"
echo "=============================================="
echo ""

# --- Blockchain et stream ---
echo "[ CONNEXION BLOCKCHAIN ]"
echo ""

read -p "  Nom de la blockchain        (ex: food-chain)            : " CHAIN
read -p "  Nom du stream               (ex: lot-alerts)            : " STREAM

echo ""

# --- Type d'alerte ---
echo "[ TYPE D'ALERTE ]"
echo ""
echo "  Types disponibles :"
echo "    1) RECALL         — Rappel officiel du lot"
echo "    2) EXPIRY_WARNING — Avertissement de péremption imminente"
echo "    3) QUALITY_HOLD   — Blocage qualité en attente d'analyse"
echo "    4) CONTAMINATION  — Contamination détectée"
echo ""

read -p "  Type d'alerte               (ex: RECALL)               : " ALERT_TYPE

echo ""

# --- Identification du lot ---
echo "[ IDENTIFICATION DU LOT ]"
echo ""

read -p "  Identifiant du lot          (ex: LOT-2025-QC-00421)    : " LOT_ID
read -p "  SKU / Code produit          (ex: FROMAGE-BRIE-250G)    : " SKU

echo ""

# --- Dates (pré-remplies avec aujourd'hui) ---
echo "[ DATES ] (appuyez sur Entrée pour accepter la date du jour : $TODAY)"
echo ""

read -p "  Date de péremption du lot   (défaut: $TODAY)           : " EXPIRY_DATE
EXPIRY_DATE=${EXPIRY_DATE:-$TODAY}
EXPIRY_YEAR_MONTH=$(echo "$EXPIRY_DATE" | cut -c1-7)

read -p "  Date de détection de l'alerte(défaut: $TODAY)          : " DETECTION_DATE
DETECTION_DATE=${DETECTION_DATE:-$TODAY}

echo ""

# --- Détail de l'alerte ---
echo "[ DÉTAIL DE L'ALERTE ]"
echo ""

read -p "  Raison de l'alerte          (ex: Contamination_Listeria): " ALERT_REASON
read -p "  Sévérité                    (ex: CRITIQUE / MAJEURE / MINEURE): " SEVERITY
read -p "  Action requise              (ex: RETRAIT_IMMEDIAT)      : " ACTION

echo ""

# --- Autorité émettrice ---
echo "[ AUTORITÉ ÉMETTRICE ]"
echo ""

read -p "  Autorité responsable        (ex: MAPAQ / ACIA / Interne): " AUTHORITY
read -p "  Référence officielle        (ex: MAPAQ-RECALL-2025-0831): " OFFICIAL_REF
read -p "  Adresse noeud émetteur      (ex: 1AuthorityNodeXxYy...) : " ISSUER_ADDRESS

echo ""

# --- Lots liés ---
echo "[ LOTS LIÉS ]"
echo ""
echo "  Entrez les lots liés séparés par des virgules,"
echo "  ou laissez vide s'il n'y en a pas."
echo ""

read -p "  Lots liés                   (ex: LOT-2025-QC-00418,LOT-2025-QC-00419): " LINKED_LOTS_RAW

echo ""

# --- Noeuds concernés ---
echo "[ NOEUDS CONCERNÉS ]"
echo ""
echo "  Entrez les adresses des noeuds concernés séparées par des virgules,"
echo "  ou laissez vide pour tous les noeuds."
echo ""

read -p "  Noeuds concernés            (ex: 1NodeA...,1NodeB...)   : " NODES_RAW

echo ""

# --- Informations complémentaires ---
echo "[ INFORMATIONS COMPLÉMENTAIRES ]"
echo ""

read -p "  URL rapport / document      (ex: https://mapaq.qc.ca/... ou vide): " REPORT_URL
read -p "  Commentaire libre           (ex: Analyse microbiologique positive): " COMMENT

echo ""

# --- Construction des tableaux JSON ---
if [ -z "$LINKED_LOTS_RAW" ]; then
  LINKED_JSON="[]"
else
  LINKED_JSON=$(echo "$LINKED_LOTS_RAW" | awk -F',' '{
    printf "[";
    for(i=1;i<=NF;i++){
      gsub(/^ +| +$/, "", $i);
      printf "\"%s\"", $i;
      if(i<NF) printf ",";
    }
    printf "]"
  }')
fi

if [ -z "$NODES_RAW" ]; then
  NODES_JSON="[]"
else
  NODES_JSON=$(echo "$NODES_RAW" | awk -F',' '{
    printf "[";
    for(i=1;i<=NF;i++){
      gsub(/^ +| +$/, "", $i);
      printf "\"%s\"", $i;
      if(i<NF) printf ",";
    }
    printf "]"
  }')
fi

if [ -z "$REPORT_URL" ]; then
  REPORT_VAL="null"
else
  REPORT_VAL="\"$REPORT_URL\""
fi

if [ -z "$COMMENT" ]; then
  COMMENT_VAL="null"
else
  COMMENT_VAL="\"$COMMENT\""
fi

KEYS="[\"LOT:$LOT_ID\", \"ALERT:$ALERT_TYPE\", \"EXP:$EXPIRY_YEAR_MONTH\", \"SKU:$SKU\"]"

DATA=$(cat <<EOF
{
  "json": {
    "schema_version"        : "1.0",
    "event_type"            : "$ALERT_TYPE",
    "timestamp_iso"         : "$TIMESTAMP",

    "lot_id"                : "$LOT_ID",
    "sku"                   : "$SKU",
    "expiry_date"           : "$EXPIRY_DATE",
    "expiry_year_month"     : "$EXPIRY_YEAR_MONTH",
    "detection_date"        : "$DETECTION_DATE",

    "alert_type"            : "$ALERT_TYPE",
    "alert_reason"          : "$ALERT_REASON",
    "severity"              : "$SEVERITY",
    "action_requise"        : "$ACTION",

    "issued_by_authority"   : "$AUTHORITY",
    "reference_officielle"  : "$OFFICIAL_REF",
    "issuer_node_address"   : "$ISSUER_ADDRESS",

    "lots_lies"             : $LINKED_JSON,
    "nodes_concernes"       : $NODES_JSON,

    "report_url"            : $REPORT_VAL,
    "commentaire"           : $COMMENT_VAL
  }
}
EOF
)

# --- Confirmation ---
echo "=============================================="
echo "  RÉCAPITULATIF"
echo "=============================================="
echo "  Blockchain  : $CHAIN"
echo "  Stream      : $STREAM"
echo "  Clés        : $KEYS"
echo "  Lot         : $LOT_ID | SKU: $SKU"
echo "  Détection   : $DETECTION_DATE"
echo "  Péremption  : $EXPIRY_DATE"
echo "  Alerte      : $ALERT_TYPE — $SEVERITY"
echo "  Raison      : $ALERT_REASON"
echo "  Autorité    : $AUTHORITY ($OFFICIAL_REF)"
echo "  Lots liés   : $LINKED_JSON"
echo "=============================================="
echo ""

if [ "$SEVERITY" = "CRITIQUE" ]; then
  echo "  /!\  SÉVÉRITÉ CRITIQUE — Cette alerte sera"
  echo "  /!\  immédiatement visible sur tous les noeuds."
  echo ""
fi

read -p "  Confirmer la publication ? (oui/non) : " CONFIRM

if [ "$CONFIRM" != "oui" ]; then
  echo ""
  echo "  Publication annulée."
  echo ""
  exit 0
fi

echo ""
echo "  Publication en cours..."
echo ""

TXID=$(multichain-cli "$CHAIN" publish "$STREAM" "$KEYS" "$DATA")

if [ $? -eq 0 ]; then
  echo "  ✓ Alerte publiée avec succès"
  echo "  ✓ TXID : $TXID"
else
  echo "  ✗ Erreur lors de la publication"
  exit 1
fi

echo ""
