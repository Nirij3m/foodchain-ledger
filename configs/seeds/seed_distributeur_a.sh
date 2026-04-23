#!/bin/bash
# =============================================================================
# seed_distributeur_a.sh
# Peuple la blockchain depuis le noeud DISTRIBUTEUR A
#
# Séquence publiée :
#   1. RECEPTION      — réception de 100 poulets en boucherie
#   2. EXPIRY_WARNING — alerte péremption imminente (J-1) détectée en rayon
#
# Produit : Poulet entier frais Label Rouge (produit animalier)
#
# Usage : bash seed_distributeur_a.sh
# =============================================================================

echo ""
echo "[ CONNEXION BLOCKCHAIN ]"
echo ""
read -p "  Nom de la blockchain        (ex: org_blockchain)        : " CHAIN
read -p "  Stream des réceptions       (ex: streamA)              : " STREAM_RECEPTIONS
read -p "  Stream des alertes          (ex: streamA)              : " STREAM_ALERTS

# --- Identités des acteurs ---
TRANSPORTEUR_ADDRESS="1TransportNodeHhIiJjKkLlMm22222"
TRANSPORTEUR_NOM="Transport Réfrigéré Laurentides"

DISTRIBUTEUR_A_ADDRESS="1DistribANodeNnOoPpQqRrSs33333"
DISTRIBUTEUR_A_NOM="Boucherie Gros-Volume Laval"

# --- Données du lot ---
LOT_ID="LOT-2025-QC-00421"
SKU="POULET-ENTIER-FRAIS-1KG5"
PRODUCT_NAME="Poulet entier frais Label Rouge 1.5 kg"
CATEGORY="volaille_fraiche"
EXPIRY_DATE="2025-04-17"
EXPIRY_YEAR_MONTH="2025-04"
QUANTITY_RECU=100
UNIT="unites"

TIMESTAMP_RECEPTION="2025-04-10T18:00:00Z"
TIMESTAMP_ALERT="2025-04-16T07:30:00Z"

echo ""
echo "=============================================="
echo "  SEED — DISTRIBUTEUR A : $DISTRIBUTEUR_A_NOM"
echo "=============================================="
echo "  Blockchain  : $CHAIN"
echo "  Lot         : $LOT_ID"
echo "  Produit     : $PRODUCT_NAME"
echo "  Reçu        : $QUANTITY_RECU $UNIT"
echo "  Péremption  : $EXPIRY_DATE"
echo "=============================================="
echo ""
echo "  Événements qui seront publiés :"
echo "    1. RECEPTION      — réception de $QUANTITY_RECU $UNIT en boucherie"
echo "    2. EXPIRY_WARNING — alerte J-1 avant péremption détectée en rayon"
echo ""
read -p "  Lancer le seed ? (oui/non) : " CONFIRM
if [ "$CONFIRM" != "oui" ]; then
  echo "  Seed annulé."
  exit 0
fi

# ==============================================================
# ÉVÉNEMENT 1 — RÉCEPTION en boucherie
# ==============================================================

echo ""
echo "  [1/2] Publication de la RÉCEPTION en boucherie..."

KEYS_R="[\"LOT:$LOT_ID\", \"EXP:$EXPIRY_YEAR_MONTH\", \"NODE:$DISTRIBUTEUR_A_ADDRESS\", \"SKU:$SKU\"]"

DATA_R=$(cat <<EOF
{
  "json": {
    "schema_version"               : "1.0",
    "event_type"                   : "reception",
    "timestamp_iso"                : "$TIMESTAMP_RECEPTION",

    "lot_id"                       : "$LOT_ID",
    "sku"                          : "$SKU",
    "product_name"                 : "$PRODUCT_NAME",
    "category"                     : "$CATEGORY",
    "batch_number"                 : "BATCH-QC-AVI-2025-0421",
    "production_date"              : "2025-04-10",
    "abattage_date"                : "2025-04-09",
    "expiry_date"                  : "$EXPIRY_DATE",
    "expiry_year_month"            : "$EXPIRY_YEAR_MONTH",

    "quantity_received"            : $QUANTITY_RECU,
    "unit"                         : "$UNIT",

    "producer_name"                : "Ferme Avicole Ste-Marie",
    "producer_country"             : "ca",
    "producer_region"              : "Chaudière-Appalaches",
    "certifications"               : ["label_rouge", "bien_etre_animal"],
    "previous_node_id"             : "$TRANSPORTEUR_ADDRESS",

    "receiving_node_address"       : "$DISTRIBUTEUR_A_ADDRESS",
    "receiving_node_name"          : "$DISTRIBUTEUR_A_NOM",
    "receiving_node_type"          : "point_de_vente",
    "gps_lat"                      : 45.5833,
    "gps_lng"                      : -73.7441,
    "operator"                     : "Groupe Boucherie Laval inc.",

    "temperature_reception_celsius": 2.5,
    "temperature_conforme"         : true,
    "packaging_intact"             : true,
    "conformity_check_passed"      : true,
    "inspector_address"            : "$DISTRIBUTEUR_A_ADDRESS",

    "transport_document_ref"       : "BL-2025-04-10-QC-0071",
    "customs_ref"                  : null,
    "recall_status"                : "none"
  }
}
EOF
)

TXID_R=$(multichain-cli "$CHAIN" publish "$STREAM_RECEPTIONS" "$KEYS_R" "$DATA_R" offchain)
if [ $? -eq 0 ]; then
  echo "      ✓ RECEPTION publiée — TXID : $TXID_R"
else
  echo "      ✗ Erreur lors de la publication de la RECEPTION"
  exit 1
fi

# ==============================================================
# ÉVÉNEMENT 2 — ALERTE péremption imminente (J-1)
# ==============================================================

echo ""
echo "  [2/2] Publication de l'ALERTE EXPIRY_WARNING (J-1)..."

KEYS_A="[\"LOT:$LOT_ID\", \"ALERT:EXPIRY_WARNING\", \"EXP:$EXPIRY_YEAR_MONTH\", \"SKU:$SKU\"]"

DATA_A=$(cat <<EOF
{
  "json": {
    "schema_version"        : "1.0",
    "event_type"            : "expiry_warning",
    "timestamp_iso"         : "$TIMESTAMP_ALERT",

    "lot_id"                : "$LOT_ID",
    "sku"                   : "$SKU",
    "expiry_date"           : "$EXPIRY_DATE",
    "expiry_year_month"     : "$EXPIRY_YEAR_MONTH",
    "detection_date"        : "2025-04-16",

    "alert_type"            : "expiry_warning",
    "alert_reason"          : "volaille_fraiche_perimant_dans_24h",
    "severity"              : "majeure",
    "action_requise"        : "retrait_rayon_et_destruction",

    "issued_by_authority"   : "interne",
    "reference_officielle"  : "INTERNAL-BGV-LAV-2025-0416-001",
    "issuer_node_address"   : "$DISTRIBUTEUR_A_ADDRESS",

    "lots_lies"             : [],
    "nodes_concernes"       : ["$DISTRIBUTEUR_A_ADDRESS"],

    "report_url"            : null,
    "commentaire"           : "Controle rayon quotidien — 18 unites encore en stock a retirer immediatement"
  }
}
EOF
)

TXID_A=$(multichain-cli "$CHAIN" publish "$STREAM_ALERTS" "$KEYS_A" "$DATA_A" offchain)
if [ $? -eq 0 ]; then
  echo "      ✓ ALERTE publiée — TXID : $TXID_A"
else
  echo "      ✗ Erreur lors de la publication de l'ALERTE"
  exit 1
fi

echo ""
echo "=============================================="
echo "  SEED DISTRIBUTEUR A TERMINÉ"
echo "  2 événements publiés sur $CHAIN"
echo "=============================================="
echo ""
