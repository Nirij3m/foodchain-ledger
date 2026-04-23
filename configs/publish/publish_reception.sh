#!/bin/bash
# =============================================================================
# publish_reception.sh
# Publie la réception d'un lot alimentaire sur la blockchain MultiChain
# Usage : bash publish_reception.sh
# =============================================================================

TODAY=$(date -u +%Y-%m-%d)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo ""
echo "=============================================="
echo "  PUBLICATION — RÉCEPTION DE LOT ALIMENTAIRE"
echo "=============================================="
echo ""

# --- Blockchain et stream ---
echo "[ CONNEXION BLOCKCHAIN ]"
echo ""

read -p "  Nom de la blockchain        (ex: food-chain)            : " CHAIN
read -p "  Nom du stream               (ex: lot-receptions)        : " STREAM

echo ""

# --- Identifiants du lot ---
echo "[ IDENTIFICATION DU LOT ]"
echo ""

read -p "  Identifiant du lot          (ex: LOT-2025-QC-00421)    : " LOT_ID
read -p "  SKU / Code produit          (ex: FROMAGE-BRIE-250G)    : " SKU
read -p "  Nom complet du produit      (ex: Brie de Meaux 250g)   : " PRODUCT_NAME
read -p "  Catégorie                   (ex: PRODUITS_LAITIERS)    : " CATEGORY
read -p "  Numéro de lot fournisseur   (ex: BATCH-FR-441-2025)    : " BATCH_NUMBER

echo ""

# --- Dates (pré-remplies avec aujourd'hui) ---
echo "[ DATES ] (appuyez sur Entrée pour accepter la date du jour : $TODAY)"
echo ""

read -p "  Date de production          (défaut: $TODAY)           : " PRODUCTION_DATE
PRODUCTION_DATE=${PRODUCTION_DATE:-$TODAY}

read -p "  Date de péremption          (défaut: $TODAY)           : " EXPIRY_DATE
EXPIRY_DATE=${EXPIRY_DATE:-$TODAY}

echo ""

# --- Quantité ---
echo "[ QUANTITÉ REÇUE ]"
echo ""

read -p "  Quantité reçue              (ex: 48)                   : " QUANTITY
read -p "  Unité                       (ex: unites / kg / caisses): " UNIT

echo ""

# --- Origine ---
echo "[ ORIGINE ET FOURNISSEUR ]"
echo ""

read -p "  Nom du producteur           (ex: Fromagerie Guilloteau) : " PRODUCER_NAME
read -p "  Pays du producteur          (ex: FR)                    : " PRODUCER_COUNTRY
read -p "  Région du producteur        (ex: Ile-de-France)         : " PRODUCER_REGION
read -p "  Certifications              (ex: AOP,BIO)               : " CERTIFICATIONS_RAW
read -p "  Adresse noeud précédent     (ex: 1SupplierNodeXxYy...)  : " PREVIOUS_NODE

echo ""

# --- Nœud récepteur ---
echo "[ NOEUD RÉCEPTEUR ]"
echo ""

read -p "  Adresse du noeud            (ex: 1FoodNode9xKpQr...)    : " NODE_ADDRESS
read -p "  Nom du noeud                (ex: Entrepot Montreal-Est) : " NODE_NAME
read -p "  Type de noeud               (ex: PRODUCTEUR / ENTREPOT_DISTRIBUTION / POINT_DE_VENTE): " NODE_TYPE
read -p "  Latitude GPS                (ex: 45.5831)               : " GPS_LAT
read -p "  Longitude GPS               (ex: -73.5041)              : " GPS_LNG
read -p "  Opérateur                   (ex: Distribution QC Inc.)  : " OPERATOR

echo ""

# --- Conditions de réception ---
echo "[ CONDITIONS DE RÉCEPTION ]"
echo ""

read -p "  Température à l'arrivée (°C)(ex: 4.2)                  : " TEMPERATURE
read -p "  Température conforme ?      (ex: true / false)          : " TEMP_OK
read -p "  Emballage intact ?          (ex: true / false)          : " PACKAGING_OK
read -p "  Contrôle conformité OK ?    (ex: true / false)          : " CONFORMITY_OK
read -p "  Adresse inspecteur          (ex: 1InspectorXxYy...)     : " INSPECTOR

echo ""

# --- Transport ---
echo "[ TRANSPORT ET TRAÇABILITÉ ]"
echo ""

read -p "  Référence document transport(ex: CMR-2025-04-19-0091)   : " TRANSPORT_REF
read -p "  Référence douanière         (ex: CUST-2025-001 ou vide) : " CUSTOMS_REF

echo ""

# --- Construction des valeurs dérivées ---
EXPIRY_YEAR_MONTH=$(echo "$EXPIRY_DATE" | cut -c1-7)

CERT_JSON=$(echo "$CERTIFICATIONS_RAW" | awk -F',' '{
  printf "[";
  for(i=1;i<=NF;i++){
    gsub(/^ +| +$/, "", $i);
    printf "\"%s\"", $i;
    if(i<NF) printf ",";
  }
  printf "]"
}')

if [ -z "$CUSTOMS_REF" ]; then
  CUSTOMS_VAL="null"
else
  CUSTOMS_VAL="\"$CUSTOMS_REF\""
fi

KEYS="[\"LOT:$LOT_ID\", \"EXP:$EXPIRY_YEAR_MONTH\", \"NODE:$NODE_ADDRESS\", \"SKU:$SKU\"]"

DATA=$(cat <<EOF
{
  "json": {
    "schema_version"               : "1.0",
    "event_type"                   : "RECEPTION",
    "timestamp_iso"                : "$TIMESTAMP",

    "lot_id"                       : "$LOT_ID",
    "sku"                          : "$SKU",
    "product_name"                 : "$PRODUCT_NAME",
    "category"                     : "$CATEGORY",
    "batch_number"                 : "$BATCH_NUMBER",
    "production_date"              : "$PRODUCTION_DATE",
    "expiry_date"                  : "$EXPIRY_DATE",
    "expiry_year_month"            : "$EXPIRY_YEAR_MONTH",

    "quantity_received"            : $QUANTITY,
    "unit"                         : "$UNIT",

    "producer_name"                : "$PRODUCER_NAME",
    "producer_country"             : "$PRODUCER_COUNTRY",
    "producer_region"              : "$PRODUCER_REGION",
    "certifications"               : $CERT_JSON,
    "previous_node_id"             : "$PREVIOUS_NODE",

    "receiving_node_address"       : "$NODE_ADDRESS",
    "receiving_node_name"          : "$NODE_NAME",
    "receiving_node_type"          : "$NODE_TYPE",
    "gps_lat"                      : $GPS_LAT,
    "gps_lng"                      : $GPS_LNG,
    "operator"                     : "$OPERATOR",

    "temperature_reception_celsius": $TEMPERATURE,
    "temperature_conforme"         : $TEMP_OK,
    "packaging_intact"             : $PACKAGING_OK,
    "conformity_check_passed"      : $CONFORMITY_OK,
    "inspector_address"            : "$INSPECTOR",

    "transport_document_ref"       : "$TRANSPORT_REF",
    "customs_ref"                  : $CUSTOMS_VAL,
    "recall_status"                : "NONE"
  }
}
EOF
)

# --- Confirmation ---
echo "=============================================="
echo "  RÉCAPITULATIF"
echo "=============================================="
echo "  Blockchain : $CHAIN"
echo "  Stream     : $STREAM"
echo "  Clés       : $KEYS"
echo "  Lot        : $LOT_ID | $PRODUCT_NAME"
echo "  Quantité   : $QUANTITY $UNIT"
echo "  Production : $PRODUCTION_DATE"
echo "  Expiry     : $EXPIRY_DATE"
echo "  Noeud      : $NODE_NAME ($NODE_TYPE)"
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

TXID=$(multichain-cli "$CHAIN" publish "$STREAM" "$KEYS" "$DATA" offchain)

if [ $? -eq 0 ]; then
  echo "  ✓ Lot publié avec succès"
  echo "  ✓ TXID : $TXID"
else
  echo "  ✗ Erreur lors de la publication"
  exit 1
fi

echo ""
