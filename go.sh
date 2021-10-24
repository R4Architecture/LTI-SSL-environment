#/bin/bash

#    .---------- constant part!
#    vvvv vvvv-- the code from above
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color


if [ "$#" -ne 1 ]
then
echo "You must supply a domain..."
exit 1
fi

DOMAIN=$1
if [[ -d certs ]]
then
    echo "certs exists on your filesystem. Let's move it for now"
    if [[ -d certs_org ]]
    then
        echo "certs_org exists on your filesystem. Let's remove it"
        rm certs_org
    fi
    mv -f certs certs_org
fi
echo "Let's create a new certs directory for development puropses"
mkdir certs

# touch openssl.cnf

# Add wildcard
WILDCARD="*.$DOMAIN"

# Set our CSR variables
SUBJ="
C=NL
ST=UT
O=Local Developement
localityName=Local Developement
commonName=$WILDCARD
organizationalUnitName=Local Developement
emailAddress=admin@$DOMAIN
"

# Generate our Private Key, CSR and Certificate
printf "\n${RED}Remember / write down the passphrase ${NC} you are going to reuse it several times"
openssl genrsa -des3 -out ./certs/localCA.key 2048

printf "${GREEN}\nThe key was created now we'll need the passphrase to create your CA certificate ${NC}"
openssl req -x509 -new -nodes -subj "$(echo -n "$SUBJ" | tr "\n" "/")" -key ./certs/localCA.key -sha256 -days 1825 -out ./certs/localCA.pem


# # openssl req -new -subj "$(echo -n "$SUBJ" | tr "\n" "/")" -key "$DOMAIN.key" -out "$DOMAIN.csr"
openssl x509 -in "./certs/localCA.pem" -inform PEM -out "./certs/localCA.crt"

printf "\nCreate a ${GREEN} private key for the wildcard ${NC} based on CA certificate"

printf '[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[dn]
C = NL
ST = UT
L = Utrecht
O = example Inc.
OU = Integration Team
emailAddress = admin@%s
CN = %s
' "$DOMAIN" "$DOMAIN" >| ./certs/$DOMAIN.csr.cnf

openssl req \
-new \
-sha256 \
-nodes \
-out ./certs/$DOMAIN.csr \
-newkey rsa:2048 \
-keyout ./certs/$DOMAIN.key \
-config ./certs/$DOMAIN.csr.cnf  


printf "\nCreate a ${GREEN} certificate for the wildcard ${NC} domain
last time we will be needing the CA key passphrase in this porces"

printf '
authorityKeyIdentifier = keyid,issuer
basicConstraints = CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = *.%s
DNS.2 = %s
' "$DOMAIN" "$DOMAIN" >| ./certs/v3.ext

openssl x509 \
-req \
-in ./certs/$DOMAIN.csr \
-CA ./certs/localCA.pem \
-CAkey ./certs/localCA.key \
-CAcreateserial \
-out ./certs/$DOMAIN.crt \
-days 500 \
-sha256 \
-extfile ./certs/v3.ext

# #still chaining needed to make proxying work!

rm ./certs/localCA.pem
rm ./certs/localCA.srl
rm ./certs/$DOMAIN.csr.cnf
rm ./certs/$DOMAIN.csr
rm ./certs/v3.ext
