#!/bin/bash
# =============================================================================
# publish_transfert.sh
# Publie le transfert d'un lot entre deux noeuds sur la blockchain MultiChain
# Usage : bash publish_transfert.sh
# =============================================================================

TODAY=$(date -u +%Y-%m-%d)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo ""
echo "=============================================="
echo "  PUBLICATION — TRANSFERT DE LOT ALIMENTAIRE"
echo "=============================================="
echo ""

# --- Blockchain et stream ---
echo "[ CONNEXION BLOCKCHAIN ]"
echo ""

read -p "  Nom de la blockchain        (ex: food-chain)            : " CHAIN
read -p "  Nom du stream               (ex: lot-transfers)         : " STREAM

echo ""

# --- Identification du lot ---
echo "[ IDENTIFICATION DU LOT ]"
echo ""

read -p "  Identifiant du lot          (ex: LOT-2025-QC-00421)    : " LOT_ID

echo ""

# --- Dates (pré-remplies avec aujourd'hui) ---
echo "[ DATES ] (appuyez sur Entrée pour accepter la date du jour : $TODAY)"
echo ""

read -p "  Date de péremption          (défaut: $TODAY)           : " EXPIRY_DATE
EXPIRY_DATE=${EXPIRY_DATE:-$TODAY}
EXPIRY_YEAR_MONTH=$(echo "$EXPIRY_DATE" | cut -c1-7)

read -p "  Date du transfert           (défaut: $TODAY)           : " TRANSFER_DATE
TRANSFER_DATE=${TRANSFER_DATE:-$TODAY}

echo ""

# --- Quantité transférée ---
echo "[ QUANTITÉ TRANSFÉRÉE ]"
echo ""

read -p "  Quantité transférée         (ex: 24)                   : " QUANTITY_TRANSFERRED
read -p "  Unité                       (ex: unites / kg / caisses): " UNIT
read -p "  Quantité restante à l'origine(ex: 24)                  : " REMAINING

echo ""

# --- Nœud expéditeur ---
echo "[ NOEUD EXPÉDITEUR ]"
echo ""

read -p "  Adresse noeud source        (ex: 1FoodNode9xKpQr...)   : " FROM_ADDRESS
read -p "  Nom noeud source            (ex: Entrepot Montreal-Est): " FROM_NAME
read -p "  Type noeud source           (ex: PRODUCTEUR / ENTREPOT_DISTRIBUTION / POINT_DE_VENTE): " FROM_TYPE

echo ""

# --- Nœud destinataire ---
echo "[ NOEUD DESTINATAIRE ]"
echo ""

read -p "  Adresse noeud destination   (ex: 1RetailNode7xMnOp...) : " TO_ADDRESS
read -p "  Nom noeud destination       (ex: IGA Plateau-Mont-Royal): " TO_NAME
read -p "  Type noeud destination      (ex: PRODUCTEUR / ENTREPOT_DISTRIBUTION / POINT_DE_VENTE): " TO_TYPE

echo ""

# --- Conditions de transport ---
echo "[ CONDITIONS DE TRANSPORT ]"
echo ""

read -p "  Température au départ (°C)  (ex: 4.0)                  : " TEMP_DEPART
read -p "  Température à l'arrivée (°C)(ex: 3.8)                  : " TEMP_ARRIVEE
read -p "  Température conforme ?      (ex: true / false)          : " TEMP_OK
read -p "  Référence document transport(ex: BL-2025-04-22-0044)   : " TRANSPORT_REF

echo ""

# --- Responsables ---
echo "[ RESPONSABLES ]"
echo ""

read -p "  Adresse signataire expéditeur  (ex: 1SenderXxYyZz...)  : " SENDER_ADDRESS
read -p "  Adresse signataire destinataire(ex: 1ReceiverXxYy...)  : " RECEIVER_ADDRESS

echo ""

# --- Construction ---
KEYS="[\"LOT:$LOT_ID\", \"FROM:$FROM_ADDRESS\", \"TO:$TO_ADDRESS\", \"EXP:$EXPIRY_YEAR_MONTH\"]"

DATA=$(cat <<EOF
{
  "json": {
    "schema_version"              : "1.0",
    "event_type"                  : "TRANSFER",
    "timestamp_iso"               : "$TIMESTAMP",

    "lot_id"                      : "$LOT_ID",
    "expiry_date"                 : "$EXPIRY_DATE",
    "expiry_year_month"           : "$EXPIRY_YEAR_MONTH",
    "transfer_date"               : "$TRANSFER_DATE",

    "quantity_transferred"        : $QUANTITY_TRANSFERRED,
    "unit"                        : "$UNIT",
    "remaining_at_origin"         : $REMAINING,

    "from_node_address"           : "$FROM_ADDRESS",
    "from_node_name"              : "$FROM_NAME",
    "from_node_type"              : "$FROM_TYPE",

    "to_node_address"             : "$TO_ADDRESS",
    "to_node_name"                : "$TO_NAME",
    "to_node_type"                : "$TO_TYPE",

    "temperature_depart_celsius"  : $TEMP_DEPART,
    "temperature_arrivee_celsius" : $TEMP_ARRIVEE,
    "temperature_conforme"        : $TEMP_OK,
    "transport_document_ref"      : "$TRANSPORT_REF",

    "sender_address"              : "$SENDER_ADDRESS",
    "receiver_address"            : "$RECEIVER_ADDRESS"
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
echo "  Lot         : $LOT_ID"
echo "  Date        : $TRANSFER_DATE"
echo "  Quantité    : $QUANTITY_TRANSFERRED $UNIT (reste: $REMAINING)"
echo "  De          : $FROM_NAME ($FROM_TYPE)"
echo "  Vers        : $TO_NAME ($TO_TYPE)"
echo "  Températures: $TEMP_DEPART°C → $TEMP_ARRIVEE°C"
echo "=============================================="
echo ""
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
  echo "  ✓ Transfert publié avec succès"
  echo "  ✓ TXID : $TXID"
else
  echo "  ✗ Erreur lors de la publication"
  exit 1
fi

echo ""
