#!/bin/bash
# =============================================================================
# seed_producteur.sh
# Peuple la blockchain depuis le noeud PRODUCTEUR
#
# Séquence publiée :
#   1. RECEPTION  — création du lot dans le système du producteur
#
# Le producteur ne publie PAS de transfert : il recense uniquement
# les lots qu'il crée. Le transfert vers le transporteur est publié
# par le transporteur lui-même.
#
# Produit : Poulet entier frais Label Rouge (produit animalier)
#
# Usage : bash seed_producteur.sh
# =============================================================================

echo ""
echo "[ CONNEXION BLOCKCHAIN ]"
echo ""
read -p "  Nom de la blockchain        (ex: org_blockchain)        : " CHAIN
read -p "  Stream des réceptions       (ex: streamA)              : " STREAM_RECEPTIONS

# --- Identités des acteurs ---
PRODUCTEUR_ADDRESS="1ProducerNodeAaBbCcDdEeFfGg11111"
PRODUCTEUR_NOM="Ferme Avicole Ste-Marie"

# --- Données du lot ---
LOT_ID="LOT-2025-QC-00421"
SKU="POULET-ENTIER-FRAIS-1KG5"
PRODUCT_NAME="Poulet entier frais Label Rouge 1.5 kg"
CATEGORY="volaille_fraiche"
BATCH_NUMBER="BATCH-QC-AVI-2025-0421"
PRODUCTION_DATE="2025-04-10"
ABATTAGE_DATE="2025-04-09"
EXPIRY_DATE="2025-04-17"
EXPIRY_YEAR_MONTH="2025-04"
QUANTITY=200
UNIT="unites"

TIMESTAMP_RECEPTION="2025-04-10T06:00:00Z"

echo ""
echo "=============================================="
echo "  SEED — PRODUCTEUR : $PRODUCTEUR_NOM"
echo "=============================================="
echo "  Blockchain  : $CHAIN"
echo "  Lot         : $LOT_ID"
echo "  Produit     : $PRODUCT_NAME"
echo "  Quantité    : $QUANTITY $UNIT"
echo "  Abattage    : $ABATTAGE_DATE"
echo "  Péremption  : $EXPIRY_DATE"
echo "=============================================="
echo ""
echo "  Événements qui seront publiés :"
echo "    1. RECEPTION  — création du lot chez le producteur"
echo ""
echo "  Note : le producteur ne publie PAS de transfert."
echo "         Il recense uniquement les lots qu'il crée."
echo ""
read -p "  Lancer le seed ? (oui/non) : " CONFIRM
if [ "$CONFIRM" != "oui" ]; then
  echo "  Seed annulé."
  exit 0
fi

# ==============================================================
# ÉVÉNEMENT 1 — RÉCEPTION (création du lot chez le producteur)
# ==============================================================

echo ""
echo "  [1/1] Publication de la RÉCEPTION..."

KEYS_R="[\"LOT:$LOT_ID\", \"EXP:$EXPIRY_YEAR_MONTH\", \"NODE:$PRODUCTEUR_ADDRESS\", \"SKU:$SKU\"]"

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
    "batch_number"                 : "$BATCH_NUMBER",
    "production_date"              : "$PRODUCTION_DATE",
    "abattage_date"                : "$ABATTAGE_DATE",
    "expiry_date"                  : "$EXPIRY_DATE",
    "expiry_year_month"            : "$EXPIRY_YEAR_MONTH",

    "quantity_received"            : $QUANTITY,
    "unit"                         : "$UNIT",

    "producer_name"                : "$PRODUCTEUR_NOM",
    "producer_country"             : "ca",
    "producer_region"              : "Chaudière-Appalaches",
    "certifications"               : ["label_rouge", "bien_etre_animal"],
    "previous_node_id"             : null,

    "receiving_node_address"       : "$PRODUCTEUR_ADDRESS",
    "receiving_node_name"          : "$PRODUCTEUR_NOM",
    "receiving_node_type"          : "producteur",
    "gps_lat"                      : 46.4471,
    "gps_lng"                      : -71.0381,
    "operator"                     : "$PRODUCTEUR_NOM",

    "temperature_reception_celsius": 2.0,
    "temperature_conforme"         : true,
    "packaging_intact"             : true,
    "conformity_check_passed"      : true,
    "inspector_address"            : "$PRODUCTEUR_ADDRESS",

    "transport_document_ref"       : null,
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

echo ""
echo "=============================================="
echo "  SEED PRODUCTEUR TERMINÉ"
echo "  1 événement publié sur $CHAIN"
echo "=============================================="
echo ""
