#!/bin/bash
# =============================================================================
# seed_transporteur.sh
# Peuple la blockchain depuis le noeud TRANSPORTEUR
#
# Séquence publiée :
#   1. TRANSFER   — livraison de 100 unités au distributeur A
#   2. TRANSFER   — livraison de 100 unités au distributeur B
#
# Le transporteur ne publie PAS de réception : il n'est
# pas propriétaire du lot, il est en transit.
#
# Produit : Poulet entier frais Label Rouge (produit animalier)
#
# Usage : bash seed_transporteur.sh
# =============================================================================

echo ""
echo "[ CONNEXION BLOCKCHAIN ]"
echo ""
read -p "  Nom de la blockchain        (ex: org_blockchain)        : " CHAIN
read -p "  Stream des transferts       (ex: streamA ou streamB)  : " STREAM_TRANSFERS

# --- Identités des acteurs ---
TRANSPORTEUR_ADDRESS="1TransportNodeHhIiJjKkLlMm22222"
TRANSPORTEUR_NOM="Transport Réfrigéré Laurentides"

DISTRIBUTEUR_A_ADDRESS="1DistribANodeNnOoPpQqRrSs33333"
DISTRIBUTEUR_A_NOM="Boucherie Gros-Volume Laval"

DISTRIBUTEUR_B_ADDRESS="1DistribBNodeTtUuVvWwXxYy44444"
DISTRIBUTEUR_B_NOM="Épicerie Fine du Marché Jean-Talon"

# --- Données du lot ---
LOT_ID="LOT-2025-QC-00421"
EXPIRY_DATE="2025-04-17"
EXPIRY_YEAR_MONTH="2025-04"
QUANTITY_VERS_A=100
QUANTITY_VERS_B=100
UNIT="unites"

TIMESTAMP_TRANSFER_A="2025-04-10T16:00:00Z"
TIMESTAMP_TRANSFER_B="2025-04-10T17:30:00Z"

echo ""
echo "=============================================="
echo "  SEED — TRANSPORTEUR : $TRANSPORTEUR_NOM"
echo "=============================================="
echo "  Blockchain  : $CHAIN"
echo "  Lot         : $LOT_ID"
echo "  Péremption  : $EXPIRY_DATE"
echo "=============================================="
echo ""
echo "  Événements qui seront publiés :"
echo "    1. TRANSFER   — $QUANTITY_VERS_A $UNIT vers $DISTRIBUTEUR_A_NOM"
echo "    2. TRANSFER   — $QUANTITY_VERS_B $UNIT vers $DISTRIBUTEUR_B_NOM"
echo ""
echo "  Note : le transporteur ne publie PAS de réception."
echo "         Il enregistre uniquement les remises aux destinataires."
echo ""
read -p "  Lancer le seed ? (oui/non) : " CONFIRM
if [ "$CONFIRM" != "oui" ]; then
  echo "  Seed annulé."
  exit 0
fi

# ==============================================================
# ÉVÉNEMENT 1 — TRANSFERT vers le distributeur A
# ==============================================================

echo ""
echo "  [1/2] Publication du TRANSFERT vers $DISTRIBUTEUR_A_NOM..."

KEYS_TA="[\"LOT:$LOT_ID\", \"FROM:$TRANSPORTEUR_ADDRESS\", \"TO:$DISTRIBUTEUR_A_ADDRESS\", \"EXP:$EXPIRY_YEAR_MONTH\"]"

DATA_TA=$(cat <<EOF
{
  "json": {
    "schema_version"              : "1.0",
    "event_type"                  : "transfer",
    "timestamp_iso"               : "$TIMESTAMP_TRANSFER_A",

    "lot_id"                      : "$LOT_ID",
    "expiry_date"                 : "$EXPIRY_DATE",
    "expiry_year_month"           : "$EXPIRY_YEAR_MONTH",
    "transfer_date"               : "2025-04-10",

    "quantity_transferred"        : $QUANTITY_VERS_A,
    "unit"                        : "$UNIT",
    "remaining_at_origin"         : $QUANTITY_VERS_B,

    "from_node_address"           : "$TRANSPORTEUR_ADDRESS",
    "from_node_name"              : "$TRANSPORTEUR_NOM",
    "from_node_type"              : "transporteur",

    "to_node_address"             : "$DISTRIBUTEUR_A_ADDRESS",
    "to_node_name"                : "$DISTRIBUTEUR_A_NOM",
    "to_node_type"                : "point_de_vente",

    "temperature_depart_celsius"  : 2.2,
    "temperature_arrivee_celsius" : 2.5,
    "temperature_conforme"        : true,
    "transport_document_ref"      : "BL-2025-04-10-QC-0071",

    "sender_address"              : "$TRANSPORTEUR_ADDRESS",
    "receiver_address"            : "$DISTRIBUTEUR_A_ADDRESS"
  }
}
EOF
)

TXID_TA=$(multichain-cli "$CHAIN" publish "$STREAM_TRANSFERS" "$KEYS_TA" "$DATA_TA" offchain)
if [ $? -eq 0 ]; then
  echo "      ✓ TRANSFERT vers A publié — TXID : $TXID_TA"
else
  echo "      ✗ Erreur lors de la publication du TRANSFERT vers A"
  exit 1
fi

# ==============================================================
# ÉVÉNEMENT 2 — TRANSFERT vers le distributeur B
# ==============================================================

echo ""
echo "  [2/2] Publication du TRANSFERT vers $DISTRIBUTEUR_B_NOM..."

KEYS_TB="[\"LOT:$LOT_ID\", \"FROM:$TRANSPORTEUR_ADDRESS\", \"TO:$DISTRIBUTEUR_B_ADDRESS\", \"EXP:$EXPIRY_YEAR_MONTH\"]"

DATA_TB=$(cat <<EOF
{
  "json": {
    "schema_version"              : "1.0",
    "event_type"                  : "transfer",
    "timestamp_iso"               : "$TIMESTAMP_TRANSFER_B",

    "lot_id"                      : "$LOT_ID",
    "expiry_date"                 : "$EXPIRY_DATE",
    "expiry_year_month"           : "$EXPIRY_YEAR_MONTH",
    "transfer_date"               : "2025-04-10",

    "quantity_transferred"        : $QUANTITY_VERS_B,
    "unit"                        : "$UNIT",
    "remaining_at_origin"         : 0,

    "from_node_address"           : "$TRANSPORTEUR_ADDRESS",
    "from_node_name"              : "$TRANSPORTEUR_NOM",
    "from_node_type"              : "transporteur",

    "to_node_address"             : "$DISTRIBUTEUR_B_ADDRESS",
    "to_node_name"                : "$DISTRIBUTEUR_B_NOM",
    "to_node_type"                : "point_de_vente",

    "temperature_depart_celsius"  : 2.2,
    "temperature_arrivee_celsius" : 2.6,
    "temperature_conforme"        : true,
    "transport_document_ref"      : "BL-2025-04-10-QC-0072",

    "sender_address"              : "$TRANSPORTEUR_ADDRESS",
    "receiver_address"            : "$DISTRIBUTEUR_B_ADDRESS"
  }
}
EOF
)

TXID_TB=$(multichain-cli "$CHAIN" publish "$STREAM_TRANSFERS" "$KEYS_TB" "$DATA_TB" offchain)
if [ $? -eq 0 ]; then
  echo "      ✓ TRANSFERT vers B publié — TXID : $TXID_TB"
else
  echo "      ✗ Erreur lors de la publication du TRANSFERT vers B"
  exit 1
fi

echo ""
echo "=============================================="
echo "  SEED TRANSPORTEUR TERMINÉ"
echo "  2 événements publiés sur $CHAIN"
echo "=============================================="
echo ""
